/**
 * KumbhMela Solid Waste Management System
 * Database Schema (PostgreSQL + PostGIS)
 */

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Profiles Table (Workers & Admins)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone_number TEXT UNIQUE,
  email TEXT UNIQUE,
  role TEXT CHECK (role IN ('admin', 'worker')) DEFAULT 'worker',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Bins Table
CREATE TABLE IF NOT EXISTS public.bins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bin_identifier TEXT UNIQUE, -- QR Code data
  location GEOGRAPHY(POINT),
  address TEXT,
  zone TEXT, -- Ram Kund, Tapovan, etc.
  status TEXT CHECK (status IN ('Empty', 'Full', 'Maintenance')) DEFAULT 'Empty',
  fill_level INT DEFAULT 0, -- 0-100%
  last_cleaned_at TIMESTAMPTZ,
  last_cleaned_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tasks / Audit Logs
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bin_id UUID REFERENCES public.bins(id) ON DELETE CASCADE,
  worker_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status TEXT CHECK (status IN ('Pending', 'Completed')) DEFAULT 'Pending',
  photo_before_url TEXT,
  photo_after_url TEXT,
  cleaned_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Real-time
ALTER PUBLICATION supabase_realtime ADD TABLE bins;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;

-- Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Bins are viewable by authenticated users." ON public.bins FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert/update bins." ON public.bins FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Workers can see assigned tasks." ON public.tasks FOR SELECT TO authenticated USING (
  worker_id = auth.uid() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Workers can update own tasks." ON public.tasks FOR UPDATE TO authenticated USING (worker_id = auth.uid());
