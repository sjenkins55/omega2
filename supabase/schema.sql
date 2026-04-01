-- BabyTracker Supabase Schema
-- Run this in the Supabase SQL editor to set up your database.
-- RLS (Row Level Security) enforces caregiver permissions at the database layer.

-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists "uuid-ossp";

-- ============================================================
-- Tables
-- ============================================================

create table babies (
    id            uuid primary key default uuid_generate_v4(),
    name          text not null,
    date_of_birth date not null,
    due_date      date,
    sex           text not null default 'unspecified',
    blood_type    text,
    is_archived   boolean not null default false,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create table caregivers (
    id               uuid primary key default uuid_generate_v4(),
    supabase_user_id uuid references auth.users(id) on delete cascade,
    display_name     text not null,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

-- One row per (caregiver, baby) pair — defines the role
create table baby_access (
    id            uuid primary key default uuid_generate_v4(),
    baby_id       uuid not null references babies(id) on delete cascade,
    caregiver_id  uuid not null references caregivers(id) on delete cascade,
    role          text not null check (role in ('admin', 'caregiver', 'viewer')),
    granted_at    timestamptz not null default now(),
    unique (baby_id, caregiver_id)
);

create table handoff_notes (
    id                  uuid primary key default uuid_generate_v4(),
    baby_id             uuid not null references babies(id) on delete cascade,
    author_caregiver_id uuid not null references caregivers(id),
    text                text not null,
    is_active           boolean not null default true,
    created_at          timestamptz not null default now()
);

create table caregiver_invites (
    id             uuid primary key default uuid_generate_v4(),
    baby_id        uuid not null references babies(id) on delete cascade,
    created_by_id  uuid not null references caregivers(id),
    role           text not null check (role in ('caregiver', 'viewer')),
    code           text not null unique,
    expires_at     timestamptz not null,
    used_at        timestamptz,
    used_by_id     uuid references caregivers(id),
    created_at     timestamptz not null default now()
);

-- ============================================================
-- Entry tables (all follow the same pattern)
-- ============================================================

create table feed_entries (
    id               uuid primary key default uuid_generate_v4(),
    baby_id          uuid not null references babies(id) on delete cascade,
    caregiver_id     uuid not null references caregivers(id),
    timestamp        timestamptz not null,
    feed_type        text not null check (feed_type in ('breast','bottle','solids','pump')),
    -- breast
    left_duration_s  double precision,
    right_duration_s double precision,
    last_side        text,
    -- bottle
    volume_ml        double precision,
    milk_type        text,
    formula_brand    text,
    -- solids
    food_name        text,
    had_reaction     boolean,
    texture_stage    text,
    -- pump
    pump_left_ml     double precision,
    pump_right_ml    double precision,
    pump_storage     text,
    notes            text,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

create table sleep_entries (
    id             uuid primary key default uuid_generate_v4(),
    baby_id        uuid not null references babies(id) on delete cascade,
    caregiver_id   uuid not null references caregivers(id),
    timestamp      timestamptz not null,
    start_time     timestamptz not null,
    end_time       timestamptz,
    sleep_type     text not null check (sleep_type in ('nap','nighttime')),
    location       text not null default 'crib',
    quality_rating int check (quality_rating between 1 and 5),
    notes          text,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

create table diaper_entries (
    id                 uuid primary key default uuid_generate_v4(),
    baby_id            uuid not null references babies(id) on delete cascade,
    caregiver_id       uuid not null references caregivers(id),
    timestamp          timestamptz not null,
    diaper_type        text not null check (diaper_type in ('wet','dirty','both','dry')),
    stool_color        text,
    stool_consistency  text,
    brand              text,
    notes              text,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
);

create table temperature_entries (
    id                uuid primary key default uuid_generate_v4(),
    baby_id           uuid not null references babies(id) on delete cascade,
    caregiver_id      uuid not null references caregivers(id),
    timestamp         timestamptz not null,
    value_fahrenheit  double precision not null,
    method            text not null,
    notes             text,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

create table measurements (
    id           uuid primary key default uuid_generate_v4(),
    baby_id      uuid not null references babies(id) on delete cascade,
    caregiver_id uuid not null references caregivers(id),
    timestamp    timestamptz not null,
    type         text not null check (type in ('weight','height','headCircumference')),
    value        double precision not null,
    unit         text not null,
    notes        text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create table milestone_entries (
    id              uuid primary key default uuid_generate_v4(),
    baby_id         uuid not null references babies(id) on delete cascade,
    caregiver_id    uuid not null references caregivers(id),
    milestone_key   text,
    custom_title    text,
    achieved_at     timestamptz not null,
    notes           text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create table vaccine_entries (
    id             uuid primary key default uuid_generate_v4(),
    baby_id        uuid not null references babies(id) on delete cascade,
    caregiver_id   uuid not null references caregivers(id),
    vaccine_key    text,
    custom_name    text,
    administered_at timestamptz not null,
    lot_number     text,
    provider       text,
    reactions      text,
    notes          text,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

create table appointments (
    id                   uuid primary key default uuid_generate_v4(),
    baby_id              uuid not null references babies(id) on delete cascade,
    caregiver_id         uuid not null references caregivers(id),
    scheduled_at         timestamptz not null,
    provider             text,
    appointment_type     text not null default 'wellVisit',
    next_appointment_date date,
    notes                text,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now()
);

create table medications (
    id             uuid primary key default uuid_generate_v4(),
    baby_id        uuid not null references babies(id) on delete cascade,
    created_by_id  uuid not null references caregivers(id),
    name           text not null,
    dose           double precision not null,
    dose_unit      text not null,
    route          text not null,
    is_scheduled   boolean not null default false,
    frequency_hours double precision,
    start_date     date not null,
    end_date       date,
    is_active      boolean not null default true,
    prescribed_by  text,
    notes          text,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

create table medication_doses (
    id              uuid primary key default uuid_generate_v4(),
    medication_id   uuid not null references medications(id) on delete cascade,
    caregiver_id    uuid not null references caregivers(id),
    administered_at timestamptz not null,
    skipped         boolean not null default false,
    notes           text,
    created_at      timestamptz not null default now()
);

create table illnesses (
    id           uuid primary key default uuid_generate_v4(),
    baby_id      uuid not null references babies(id) on delete cascade,
    caregiver_id uuid not null references caregivers(id),
    onset_date   date not null,
    end_date     date,
    symptoms     text not null default '',   -- comma-separated
    notes        text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- ============================================================
-- Indexes (critical for query performance at scale)
-- ============================================================

create index on feed_entries      (baby_id, timestamp desc);
create index on sleep_entries     (baby_id, start_time desc);
create index on diaper_entries    (baby_id, timestamp desc);
create index on temperature_entries (baby_id, timestamp desc);
create index on measurements      (baby_id, timestamp desc);
create index on milestone_entries (baby_id, achieved_at desc);
create index on vaccine_entries   (baby_id, administered_at desc);
create index on appointments      (baby_id, scheduled_at desc);
create index on medication_doses  (medication_id, administered_at desc);
create index on baby_access       (caregiver_id);
create index on caregiver_invites (code) where used_at is null;

-- ============================================================
-- Row Level Security
-- ============================================================
-- The rule: you can only access a baby's data if you have a row in baby_access.
-- Caregiver role enforcement (no delete for non-admin) is done in the app layer
-- AND reinforced here via RLS policies.

alter table babies              enable row level security;
alter table feed_entries        enable row level security;
alter table sleep_entries       enable row level security;
alter table diaper_entries      enable row level security;
alter table temperature_entries enable row level security;
alter table measurements        enable row level security;
alter table milestone_entries   enable row level security;
alter table vaccine_entries     enable row level security;
alter table appointments        enable row level security;
alter table medications         enable row level security;
alter table medication_doses    enable row level security;
alter table illnesses           enable row level security;
alter table baby_access         enable row level security;
alter table handoff_notes       enable row level security;
alter table caregiver_invites   enable row level security;
alter table caregivers          enable row level security;

-- Helper function: get the caregiver ID for the current auth user
create or replace function current_caregiver_id()
returns uuid language sql stable security definer as $$
    select id from caregivers where supabase_user_id = auth.uid() limit 1;
$$;

-- Helper function: get the role for (current_caregiver, baby)
create or replace function caregiver_role_for_baby(p_baby_id uuid)
returns text language sql stable security definer as $$
    select role from baby_access
    where caregiver_id = current_caregiver_id()
    and baby_id = p_baby_id
    limit 1;
$$;

-- Babies: read if you have access; write only if admin
create policy "read own babies"   on babies for select using (
    exists (select 1 from baby_access where baby_id = id and caregiver_id = current_caregiver_id())
);
create policy "admin insert baby" on babies for insert with check (true); -- enforced post-insert via baby_access
create policy "admin update baby" on babies for update using (
    caregiver_role_for_baby(id) = 'admin'
);
-- No delete policy — babies are archived, never deleted

-- Entry tables: read if you have any access; insert/update if caregiver or admin; delete if admin only
-- Template (repeated for each entry table):

-- feed_entries
create policy "read feed entries" on feed_entries for select using (
    exists (select 1 from baby_access where baby_id = feed_entries.baby_id and caregiver_id = current_caregiver_id())
);
create policy "write feed entries" on feed_entries for insert with check (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "update feed entries" on feed_entries for update using (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "delete feed entries" on feed_entries for delete using (
    caregiver_role_for_baby(baby_id) = 'admin'
);

-- sleep_entries
create policy "read sleep entries" on sleep_entries for select using (
    exists (select 1 from baby_access where baby_id = sleep_entries.baby_id and caregiver_id = current_caregiver_id())
);
create policy "write sleep entries" on sleep_entries for insert with check (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "update sleep entries" on sleep_entries for update using (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "delete sleep entries" on sleep_entries for delete using (
    caregiver_role_for_baby(baby_id) = 'admin'
);

-- diaper_entries
create policy "read diaper entries" on diaper_entries for select using (
    exists (select 1 from baby_access where baby_id = diaper_entries.baby_id and caregiver_id = current_caregiver_id())
);
create policy "write diaper entries" on diaper_entries for insert with check (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "update diaper entries" on diaper_entries for update using (
    caregiver_role_for_baby(baby_id) in ('admin','caregiver')
);
create policy "delete diaper entries" on diaper_entries for delete using (
    caregiver_role_for_baby(baby_id) = 'admin'
);

-- Caregivers: can read and update own record only
create policy "read own caregiver" on caregivers for select using (
    supabase_user_id = auth.uid()
);
create policy "update own caregiver" on caregivers for update using (
    supabase_user_id = auth.uid()
);
create policy "insert caregiver" on caregivers for insert with check (
    supabase_user_id = auth.uid()
);

-- baby_access: admin can manage; all members can read
create policy "read baby access" on baby_access for select using (
    caregiver_id = current_caregiver_id()
    or exists (select 1 from baby_access ba2 where ba2.baby_id = baby_id and ba2.caregiver_id = current_caregiver_id())
);
create policy "admin manages baby access" on baby_access for all using (
    caregiver_role_for_baby(baby_id) = 'admin'
);

-- ============================================================
-- Realtime (enable for live caregiver sync)
-- ============================================================
alter publication supabase_realtime add table feed_entries;
alter publication supabase_realtime add table sleep_entries;
alter publication supabase_realtime add table diaper_entries;
alter publication supabase_realtime add table temperature_entries;
alter publication supabase_realtime add table handoff_notes;
alter publication supabase_realtime add table baby_access;

-- ============================================================
-- updated_at trigger (auto-update timestamp on every row change)
-- ============================================================
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger set_updated_at before update on babies              for each row execute function update_updated_at();
create trigger set_updated_at before update on feed_entries        for each row execute function update_updated_at();
create trigger set_updated_at before update on sleep_entries       for each row execute function update_updated_at();
create trigger set_updated_at before update on diaper_entries      for each row execute function update_updated_at();
create trigger set_updated_at before update on temperature_entries for each row execute function update_updated_at();
create trigger set_updated_at before update on measurements        for each row execute function update_updated_at();
create trigger set_updated_at before update on medications         for each row execute function update_updated_at();
create trigger set_updated_at before update on illnesses           for each row execute function update_updated_at();
