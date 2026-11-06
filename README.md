# Asesmen Fikih Online 2026 — MTS Raudlatul Ulum VI

Starter aplikasi web dengan halaman siswa, timer 90 menit, navigasi/penanda soal, koreksi di PostgreSQL, hasil privat siswa, dan dashboard admin.

## Catatan sebelum digunakan
- Aplikasi belum online dan belum terhubung ke proyek Supabase sekolah.
- Guru wajib menelaah 50 soal contoh sesuai buku/kurikulum Fikih yang digunakan.
- Logo masih placeholder.
- Sesi siswa menggunakan Supabase Anonymous Auth. Hasil hanya dapat dibuka pada sesi/browser yang sama. Jika browser/cache dihapus atau siswa pindah perangkat, pemulihan memerlukan prosedur admin.

## 1. Buat proyek Supabase
1. Buat project di https://supabase.com.
2. Salin Project URL dan anon/publishable key dari Project Settings → API.
3. Authentication → Providers, aktifkan Anonymous Sign-Ins.
4. Jalankan `supabase/schema.sql` di SQL Editor, lalu jalankan `supabase/seed.sql`.
5. Authentication → Users → Add user untuk membuat akun admin.
6. Catat UUID admin, lalu jalankan SQL (ganti UUID):
   `insert into public.profiles(id,role) values ('UUID-ADMIN-DARI-AUTH','admin') on conflict(id) do update set role='admin';`
7. Jangan pernah membuat policy publik untuk `answer_keys`.

## 2. Konfigurasi
Edit `src/config.js`: isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY`. Keduanya boleh di frontend. Jangan pernah memasukkan `service_role` key ke HTML/JS atau GitHub.

## 3. Jalankan lokal
Gunakan VS Code + Live Server atau jalankan server static lokal. Aplikasi memakai Supabase JS ESM dari esm.sh.

## 4. Deploy Netlify
1. Upload folder ke GitHub.
2. Netlify → Add new site → Import from Git.
3. Build command kosong; publish directory `.`.
4. Tambahkan domain Netlify pada Supabase Authentication → URL Configuration.
5. Bagikan URL HTTPS kepada siswa. Alternatif: Vercel dengan output directory `.`.

## 5. Logo
Buat folder `assets`, simpan logo sebagai `logo-pesantren.png`, lalu ganti placeholder `.logo-slot` pada `src/app.js` dengan elemen img. Tambahkan CSS: `.logo-slot img{width:100%;height:100%;object-fit:contain;padding:8px}`.

## 6. Penggunaan
Admin login melalui tombol Masuk Admin, lalu dapat melihat rekap dan mengunduh CSV. Siswa membuka link, mengisi identitas, mengerjakan, meninjau, dan mengumpulkan jawaban.

## 7. Uji sebelum dipakai
Uji nomor peserta ganda, submit dua kali, penilaian, RLS siswa/admin, timer, tampilan HP, CSV, serta koneksi terputus. Jalankan tes dengan akun siswa dan admin percobaan terlebih dahulu.

## Catatan teknis penting
Jawaban sementara pada versi starter ini tersimpan di localStorage browser dan dikirim ke server saat submit; belum ada autosave server-side per klik. Karena itu koneksi internet perlu stabil dan siswa sebaiknya tidak menghapus data browser selama ujian. Fitur autosave server-side, pemulihan sesi lintas perangkat, pengacakan opsi yang konsisten dengan koreksi, serta edit/hapus data admin perlu disempurnakan sebelum ujian resmi skala besar.
