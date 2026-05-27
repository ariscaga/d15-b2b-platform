-- Fix handle_new_user trigger to explicitly set search_path
-- Required for security definer to bypass RLS on public.users insert
alter function public.handle_new_user() security definer set search_path = public;
