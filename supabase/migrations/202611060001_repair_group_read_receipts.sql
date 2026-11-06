-- Repair group read receipts for Arya Peyvand
-- Apply this file in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.group_reads (
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE public.group_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can view group read positions"
ON public.group_reads
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.group_members gm
    WHERE gm.group_id = group_reads.group_id
      AND gm.user_id = (SELECT auth.uid())
  )
);

GRANT SELECT ON public.group_reads TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_group_read(
  p_gid uuid,
  p_upto timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_read_at timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_gid IS NULL THEN
    RAISE EXCEPTION 'Group id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.group_members gm
    WHERE gm.group_id = p_gid
      AND gm.user_id = v_user
  ) THEN
    RAISE EXCEPTION 'You are not a member of this group';
  END IF;

  v_read_at := LEAST(COALESCE(p_upto, now()), now());

  INSERT INTO public.group_reads (group_id, user_id, last_read_at)
  VALUES (p_gid, v_user, v_read_at)
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET last_read_at =
    GREATEST(public.group_reads.last_read_at, EXCLUDED.last_read_at);
END;
$$;

REVOKE ALL ON FUNCTION public.mark_group_read(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_group_read(uuid, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION public.group_unread_counts()
RETURNS TABLE(group_id uuid, unread bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT
    gm.group_id,
    COUNT(msg.id)::bigint AS unread
  FROM public.group_members gm
  LEFT JOIN public.group_reads gr
    ON gr.group_id = gm.group_id
   AND gr.user_id = v_user
  LEFT JOIN public.group_messages msg
    ON msg.group_id = gm.group_id
   AND msg.sender_id <> v_user
   AND msg.created_at >= gm.joined_at
   AND msg.created_at > COALESCE(gr.last_read_at, '-infinity'::timestamptz)
   AND NOT EXISTS (
     SELECT 1
     FROM public.group_message_hides gh
     WHERE gh.message_id = msg.id
       AND gh.user_id = v_user
   )
  WHERE gm.user_id = v_user
  GROUP BY gm.group_id;
END;
$$;

REVOKE ALL ON FUNCTION public.group_unread_counts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_unread_counts() TO authenticated;

CREATE INDEX IF NOT EXISTS group_messages_group_created_at_idx
ON public.group_messages (group_id, created_at);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'group_reads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_reads;
  END IF;
END;
$$;
