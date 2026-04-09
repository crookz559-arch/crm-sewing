-- ============================================================
-- CRM Швейный цех — Supabase Schema
-- Выполнить в Supabase Dashboard → SQL Editor
-- ============================================================

-- Включаем расширение для UUID
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. ПОЛЬЗОВАТЕЛИ
-- ============================================================
create table public.users (
  id          uuid references auth.users(id) on delete cascade primary key,
  name        text not null,
  phone       text,
  role        text not null check (role in ('director','head_manager','manager','seamstress')),
  language    text not null default 'ru' check (language in ('ru','uz','ky')),
  avatar_url  text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Автоматически создаём запись при регистрации
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    coalesce(new.raw_user_meta_data->>'role', 'seamstress')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 2. КЛИЕНТЫ
-- ============================================================
create table public.clients (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  phone       text,
  email       text,
  source      text check (source in ('whatsapp','instagram','website','personal','wholesale')),
  notes       text,
  created_by  uuid references public.users(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ============================================================
-- 3. ЗАКАЗЫ
-- ============================================================
create table public.orders (
  id            uuid primary key default uuid_generate_v4(),
  title         text not null,
  description   text,
  client_id     uuid references public.clients(id),
  source        text check (source in ('whatsapp','instagram','website','personal','wholesale')),
  status        text not null default 'new'
                check (status in ('new','accepted','sewing','quality','ready','delivery','closed','rework')),
  deadline      date,
  price         numeric(12,2),           -- скрыто для role=manager
  assigned_to   uuid references public.users(id),
  created_by    uuid references public.users(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- История статусов заказа
create table public.order_history (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references public.orders(id) on delete cascade,
  status      text not null,
  note        text,
  changed_by  uuid references public.users(id),
  created_at  timestamptz not null default now()
);

-- Автоматически пишем историю при смене статуса
create or replace function public.log_order_status()
returns trigger language plpgsql as $$
begin
  if old.status is distinct from new.status then
    insert into public.order_history(order_id, status, changed_by)
    values (new.id, new.status, new.assigned_to);
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger order_status_changed
  before update on public.orders
  for each row execute procedure public.log_order_status();

-- ============================================================
-- 4. ЗАДАЧИ
-- ============================================================
create table public.tasks (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  description text,
  order_id    uuid references public.orders(id) on delete set null,
  status      text not null default 'pending'
              check (status in ('pending','in_progress','done')),
  deadline    date,
  assigned_to uuid references public.users(id),
  created_by  uuid references public.users(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ============================================================
-- 5. ДНЕВНИК ШВЕЙ
-- ============================================================
create table public.diary_entries (
  id            uuid primary key default uuid_generate_v4(),
  seamstress_id uuid not null references public.users(id) on delete cascade,
  description   text not null,
  quantity      int not null default 1,
  photos        text[],                   -- массив URL из Supabase Storage
  salary_amount numeric(10,2),            -- проставляет менеджер/директор
  approved_by   uuid references public.users(id),
  approved_at   timestamptz,
  entry_date    date not null default current_date,
  created_at    timestamptz not null default now()
);

-- ============================================================
-- 6. КУРЬЕРЫ
-- ============================================================
create table public.courier_logs (
  id          uuid primary key default uuid_generate_v4(),
  direction   text not null check (direction in ('in','out')),
  client_id   uuid references public.clients(id),
  from_who    text,
  to_who      text,
  description text not null,
  delivery_date date not null default current_date,
  order_id    uuid references public.orders(id),
  created_by  uuid references public.users(id),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 7. ПЛАН ПО ВЫРУЧКЕ
-- ============================================================
create table public.monthly_plans (
  id              uuid primary key default uuid_generate_v4(),
  year            int not null,
  month           int not null check (month between 1 and 12),
  target_revenue  numeric(14,2) not null,
  created_by      uuid references public.users(id),
  created_at      timestamptz not null default now(),
  unique(year, month)
);

-- ============================================================
-- 8. ЧАТ
-- ============================================================
create table public.chat_messages (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id),
  content     text not null,
  reply_to    uuid references public.chat_messages(id),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 9. УВЕДОМЛЕНИЯ
-- ============================================================
create table public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  type        text not null,             -- 'order_ready','deadline','assigned'
  title       text not null,
  body        text,
  related_id  uuid,                      -- id заказа или задачи
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

alter table public.users           enable row level security;
alter table public.clients         enable row level security;
alter table public.orders          enable row level security;
alter table public.order_history   enable row level security;
alter table public.tasks           enable row level security;
alter table public.diary_entries   enable row level security;
alter table public.courier_logs    enable row level security;
alter table public.monthly_plans   enable row level security;
alter table public.chat_messages   enable row level security;
alter table public.notifications   enable row level security;

-- Вспомогательная функция: роль текущего пользователя
create or replace function public.current_role()
returns text language sql security definer as $$
  select role from public.users where id = auth.uid()
$$;

-- USERS: каждый видит всех активных, редактирует только себя
create policy "users_select" on public.users for select
  using (is_active = true);
create policy "users_update_self" on public.users for update
  using (id = auth.uid());

-- CLIENTS: все авторизованные пользователи
create policy "clients_all" on public.clients for all
  using (auth.uid() is not null);

-- ORDERS: все видят, менеджеры не видят price (обрабатывается на клиенте)
create policy "orders_select" on public.orders for select
  using (auth.uid() is not null);
create policy "orders_insert" on public.orders for insert
  with check (
    public.current_role() in ('director','head_manager','manager')
  );
create policy "orders_update" on public.orders for update
  using (auth.uid() is not null)
  with check (
    public.current_role() in ('director','head_manager','manager')
  );

-- ORDER_HISTORY: только чтение для всех
create policy "order_history_select" on public.order_history for select
  using (auth.uid() is not null);
create policy "order_history_insert" on public.order_history for insert
  with check (auth.uid() is not null);

-- TASKS: все
create policy "tasks_all" on public.tasks for all
  using (auth.uid() is not null);

-- DIARY: швея видит только своё, остальные — все записи
create policy "diary_select" on public.diary_entries for select
  using (
    seamstress_id = auth.uid()
    or public.current_role() in ('director','head_manager','manager')
  );
create policy "diary_insert" on public.diary_entries for insert
  with check (seamstress_id = auth.uid());
create policy "diary_update" on public.diary_entries for update
  using (
    seamstress_id = auth.uid()
    or public.current_role() in ('director','head_manager')
  );

-- COURIERS: все авторизованные (кроме швей — фильтр на клиенте)
create policy "couriers_all" on public.courier_logs for all
  using (auth.uid() is not null);

-- MONTHLY PLANS: только директор и ГМ пишут, все видят
create policy "plans_select" on public.monthly_plans for select
  using (auth.uid() is not null);
create policy "plans_write" on public.monthly_plans for insert
  with check (public.current_role() in ('director','head_manager'));
create policy "plans_update" on public.monthly_plans for update
  using (public.current_role() in ('director','head_manager'));

-- CHAT: все
create policy "chat_all" on public.chat_messages for all
  using (auth.uid() is not null);

-- NOTIFICATIONS: только свои
create policy "notif_select" on public.notifications for select
  using (user_id = auth.uid());
create policy "notif_update" on public.notifications for update
  using (user_id = auth.uid());
create policy "notif_insert" on public.notifications for insert
  with check (auth.uid() is not null);

-- ============================================================
-- REALTIME (для чата и уведомлений)
-- ============================================================
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.orders;

-- ============================================================
-- STORAGE BUCKET для фото дневника
-- ============================================================
-- В Supabase Dashboard → Storage → New bucket: "diary-photos"
-- Public: false
-- Настроить политики доступа:
--   INSERT: auth.uid() = seamstress_id (из diary_entries)
--   SELECT: authenticated users
