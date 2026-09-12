\echo '=== TABLAS Y RLS ==='
select c.relname as tabla, c.relrowsecurity as rls_habilitado,
       (select count(*) from pg_policies p where p.tablename=c.relname) as politicas
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' order by c.relname;

\echo ''
\echo '=== POLITICAS RLS ==='
select tablename, policyname, cmd, qual from pg_policies where schemaname='public' order by tablename, policyname;

\echo ''
\echo '=== CHECK CONSTRAINTS ==='
select rel.relname as tabla, con.conname, pg_get_constraintdef(con.oid) as definicion
from pg_constraint con join pg_class rel on rel.oid=con.conrelid
join pg_namespace n on n.oid=rel.relnamespace
where n.nspname='public' and con.contype='c' order by rel.relname, con.conname;

\echo ''
\echo '=== CLAVES FORANEAS ==='
select rel.relname as tabla, pg_get_constraintdef(con.oid) as definicion
from pg_constraint con join pg_class rel on rel.oid=con.conrelid
join pg_namespace n on n.oid=rel.relnamespace
where n.nspname='public' and con.contype='f' order by rel.relname;

\echo ''
\echo '=== UNIQUE ==='
select rel.relname as tabla, pg_get_constraintdef(con.oid) as definicion
from pg_constraint con join pg_class rel on rel.oid=con.conrelid
join pg_namespace n on n.oid=rel.relnamespace
where n.nspname='public' and con.contype='u' order by rel.relname;

\echo ''
\echo '=== TRIGGERS ==='
select tgname, relname, pg_get_triggerdef(t.oid) from pg_trigger t join pg_class c on c.oid=t.tgrelid where not tgisinternal;
