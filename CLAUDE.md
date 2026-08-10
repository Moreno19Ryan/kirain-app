# KIRAIN — Spesifikasi Produk & Teknis (v1 Planning Doc)

> Dokumen ini adalah hasil kompilasi brainstorming lengkap soal aplikasi KIRAIN. Ditulis biar bisa jadi rujukan utama (termasuk buat Claude Code) pas mulai eksekusi coding, mockup, dan roadmap.

---

## 0. Aturan Kerja (WAJIB DIBACA SEBELUM EKSEKUSI APAPUN)

> Bagian ini berlaku buat Claude Code (atau instance Claude manapun) yang kerja langsung di codebase KIRAIN.

- **JANGAN** jalankan migration atau perubahan skema database apapun tanpa konfirmasi eksplisit dari Reno berupa **"OK, jalankan"**. Ini pelajaran mahal dari insiden production migration tanpa approval di GENSITI — jangan diulang di sini.
- **Project Supabase**: pastikan selalu kerja di project **development/staging**, BUKAN project production, kecuali sudah dikonfirmasi eksplisit bahwa perubahan siap ke production.
- Selalu buat **branch baru** buat tiap fitur/perubahan, jangan langsung commit ke `main`.
- Kalau ragu soal keputusan produk/fitur yang belum jelas di dokumen ini, **tanya dulu ke Reno**, jangan asumsi sendiri — terutama buat hal yang menyentuh data finansial user (perhitungan budget, kategori wajib/keinginan, dll).
- Ikuti tone & terminology yang udah ditetapkan di bagian **6. Voice & Terminology Guide** — jangan pakai bahasa formal/korporat di UI atau microcopy manapun.
- Scope fitur mengikuti pembagian **V1 vs V2+** di bagian 4 & 5 — jangan menambah fitur di luar scope V1 tanpa dikonfirmasi dulu, biar nggak scope creep.

---

## 1. Overview

- **Nama app**: **KIRAIN** (stylization: huruf kapital semua)
- **Nama lengkap**: "Kirain - Asisten Keuanganmu"
- **Jenis proyek**: Side project pribadi, terpisah total dari GENSITI. Tujuan: belajar, having fun, portofolio, potensi side income jangka panjang.
- **Developer**: Solo dev (Reno), dikerjain di sela kerja (karyawan swasta, UMR) + kuliah.
- **Platform awal**: Native mobile Android (Play Store + Galaxy Store). iOS/App Store bisa nyusul kalau Flutter dipakai (cross-platform).

---

## 2. Brand & Positioning

**Insight/pain point awal:**
Anak muda (Gen Z/Milenial) sering susah bedain kebutuhan wajib vs keinginan, dan susah konsisten nyatet keuangan karena tergantung mood/effort tinggi di app finance kebanyakan.

**Diferensiasi utama:**
Bukan sekadar pencatat transaksi (red ocean market — udah banyak Money Lover, Monefy, Spendee, PINA, dll), tapi **"decision layer"** — bantu user mikir sebelum belanja, bukan cuma nyatet setelahnya.

**Persona/Karakter app:**
- **Asisten** — bukan "temen deket" yang usil terus, bukan juga "aplikasi korporat" yang kaku
- **Tone: "santai yang serius pas dibutuhkan"**
  - Kondisi normal → santai, kadang bercanda dikit
  - Kondisi warning (mendekati limit) → netral-informatif, mulai gak lucu-lucuan
  - Kondisi kritis (defisit/mau checkout padahal wajib belum kepenuhi) → jelas & langsung, tapi tetap gak nge-judge
- **Budaya**: mix — netral secara default (universal, gak eksklusif), dengan sentuhan lokal/islami yang nyempil natural (infak/zakat sebagai kategori wajib, peringatan riba, dll), bukan dominan terus-menerus

**Target user:**
Awalnya komunitas Generus (unfair advantage: distribusi & trust), tapi didesain **universal** — gak dibatasi status pernikahan, umur, atau circle tertentu. Kalau responnya bagus, siap di-scale ke luar.

**Tagline (draft, belum final):**
- "Kirain cukup, taunya boncos."
- "Biar gak kirain-kirain lagi."
- "Sebelum kirain, cek dulu."

**Nama untuk App Store listing:**
"Kirain - Asisten Keuanganmu"

---

## 3. Arsitektur Teknis

### Stack
- **Frontend**: Flutter (native mobile, cross-platform siap kalau mau ke iOS nanti)
- **Backend**: Supabase — **project baru, terpisah total dari GENSITI**
- **Auth**: Supabase Auth (pertimbangkan magic link/OTP biar lebih ramah buat user awam, dibanding password)

### Model Data: Cloud-Primary + Local Write-Ahead Queue
> **PENTING**: Ini BUKAN local-first murni (ala WhatsApp dengan sync 2 arah). Ini juga bukan pure cloud-first tanpa buffer.

- **Supabase = source of truth utama**
- **Local queue/cache ringan** dipakai HANYA sebagai buffer kondisi offline:
  - Transaksi yang gagal terkirim (gak ada internet) disimpen dulu di antrian lokal
  - Auto-retry & auto-kirim begitu koneksi balik online
  - User tetap lihat transaksinya "tercatat" di UI dengan indikator kecil "belum tersinkron"
- **TIDAK ADA** conflict resolution kompleks / bidirectional sync — karena cloud tetap 1 sumber kebenaran
- Reinstall/ganti HP: otomatis balik normal setelah login ulang (data di cloud, gak perlu restore manual)

### Keamanan Development (Staging vs Production)
> **Belum final — 2 opsi didiskusikan, pilih salah satu atau kombinasi sebelum mulai coding:**
1. Project Supabase kedua khusus dev/testing (`kirain-dev` terpisah dari `kirain-prod`) — paling aman, effort kecil (gratis di tier Free)
2. PR + CI/CD gate di GitHub (migration hanya jalan otomatis setelah merge ke `main`, gak pernah manual ke production) — cukup aman buat human error, tapi TIDAK melindungi dari kesalahan desain skema yang baru ketahuan setelah kena production

**Rekomendasi:** kombinasi keduanya kalau memungkinkan, minimal salah satu HARUS ada (jangan ulangi insiden migration GENSITI).

### Requirement Teknis Lain
- **Minimum Android**: 8.0 Oreo (API 26)
- **Target ukuran APK**: di bawah 30–50MB
- **Performance**: lazy loading riwayat transaksi (jangan load semua sekaligus), compress asset
- **Crash monitoring**: Firebase Crashlytics (gratis, ringan, integrasi gampang di Flutter)
- **Notification channels** (Android): dipisah jadi "Reminder Harian", "Peringatan Budget", "Update & Info" — biar user bisa matiin sebagian tanpa matiin semua

### Pola yang Bisa "Dipelajari Ulang" dari GENSITI
- Pattern RLS (row-level security) — disederhanakan karena KIRAIN cuma butuh per-user isolation, gak perlu role-based setingkat GENSITI
- RPC functions (Postgres) buat kalkulasi kompleks (total wajib/keinginan) — di database layer, bukan di client
- Kebiasaan dokumentasi terstruktur (CLAUDE.md-style) dari awal proyek
- Guardrail migration dari pelajaran insiden GENSITI

---

## 4. Fitur — Scope V1 (Rilis Pertama)

### Core / Wajib Ada
- [ ] **Quick-add transaksi** — 2-3 tap, minimal friction
- [ ] **Toggle Wajib vs Keinginan** di tiap transaksi (fitur diferensiasi utama)
- [ ] **Income tracking** — kategori: Gaji, Freelance/Sampingan, THR/Bonus, Lainnya (fondasi kalkulasi wajib/keinginan)
- [ ] **Dashboard** — progress bar visual sisa budget wajib vs keinginan
- [ ] **Kategori custom** (user bisa tambah/edit/hapus), default kategori di bawah
- [ ] **Riwayat transaksi** dengan **search & filter** (kategori, range tanggal, teks catatan)
- [ ] **Catatan teks bebas** di tiap transaksi (foto struk ditunda ke v2)
- [ ] **Siklus budget custom** — user set tanggal mulai siklus (bukan cuma tanggal 1)
- [ ] **Budget rollover** — default carry-over ke bulan depan, ada toggle buat matiin
- [ ] **Budget alert per kategori** — threshold default 80%, bisa custom per kategori
- [ ] **Transaksi berulang / recurring** — termasuk cicilan (masuk kategori Wajib otomatis)
- [ ] **Deteksi transaksi duplikat** — soft warning, bukan blocking
- [ ] **Batch entry ringan** — tombol "Tambah Lagi" setelah nyatet, tanpa balik ke home
- [ ] **Target Nabung / savings goal** — termasuk Dana Darurat sebagai salah satu jenis target (bukan kategori struktural terpisah)
- [ ] **Multiple goal prioritization** — drag-reorder urutan prioritas target
- [ ] **Perbandingan antar periode** — indikator simpel "naik/turun X% dari bulan lalu"
- [ ] **Transparansi perhitungan** — breakdown yang bisa di-expand/tap, bukan black box
- [ ] **Auto-collapse kategori kosong** — kategori yang belum pernah dipakai disembunyikan dari list utama
- [ ] **Handling saldo negatif** — tampil jelas (warna merah) tapi tone tetap suportif, gak menghakimi
- [ ] **Peringatan riba/paylater** — soft notice kontekstual (bukan sistem deteksi otomatis agresif), edukatif bukan menghakimi
- [ ] **Tips edukasi finansial ringan** — 1 tips random per kunjungan Home, konten ditulis manual (20-30 tips), bisa di-dismiss
- [ ] **Reminder kontekstual gajian** — notif pas masuk siklus budget baru, ajak alokasi ke Target dulu
- [ ] **Retroactive entry** — opsi isi transaksi dari awal bulan pas onboarding pertama kali (biar rekap gak "kepotong")

### UX & Onboarding
- [ ] Onboarding maksimal 3 layar, ada opsi **Skip**
- [ ] Empty state yang "hidup" (microcopy + CTA jelas, bukan layar kosong)
- [ ] Loading state pakai skeleton screen (bukan spinner polos)
- [ ] Error state jelas + actionable (tombol retry, bahasa sesuai brand, hindari jargon teknis)
- [ ] Splash screen simpel (logo + nama, durasi singkat)
- [ ] Bottom navigation 4 tab: **Home / Catat / Rekap / Kamu**
- [ ] Dark mode (v1, bukan nyusul)
- [ ] App shortcuts — long-press icon langsung ke "Catat Transaksi"
- [ ] Widget home screen — ringkasan sisa budget + quick-add
- [ ] FAQ/Help Center sederhana di dalam app (statis)
- [ ] Aksesibilitas dasar: kontras warna cukup, tap target min 48x48dp, font ngikut sistem device

### Keamanan & Privasi
- [ ] App lock — biometric (default kalau device support) + PIN (fallback)
- [ ] Hapus akun & data — self-service dari halaman Profil, bukan cuma via kontak manual
- [ ] Privacy Policy (data gak dikirim ke pihak ketiga selain Supabase sebagai processor)
- [ ] Terms of Service (lihat bagian 7)
- [ ] Google Play Data Safety form — disiapkan jujur & jelas sebelum submit

### Data & Export
- [ ] Export **CSV** (prioritas utama v1)
- [ ] Export PDF — nice-to-have, nyusul kalau CSV udah beres duluan

### Support
- [ ] Channel support: **WA Bisnis** + **email**
- [ ] Grup WA kecil khusus beta tester (5-10 orang dari circle Generus), terpisah dari WA Bisnis support resmi

### Kategori Default

**Wajib:**
Makan & Minum · Transportasi · Tempat Tinggal · Tagihan (listrik/air/internet/pulsa) · Infak/Zakat · Kesehatan

**Keinginan:**
Jajan & Nongkrong · Hiburan · Belanja · Hobi

**Pemasukan:**
Gaji · Freelance/Sampingan · THR/Bonus · Lainnya

---

## 5. Fitur — Roadmap Setelah V1

### v1.1 (effort kecil-menengah, impact tinggi)
- Export PDF
- Foto struk di transaksi

### v1.2
- Kalender musiman (Ramadan/Lebaran) — konten kontekstual pengeluaran
- Import data CSV dari sumber lain (Excel/app lain)

### v1.3
- Mode "berdua" / shared budget (siapkan konsep schema dari awal, misal `household_id`, walau fitur baru dieksekusi di sini)
- Audit trail edit transaksi (relevan begitu shared budget ada)

### v2.0+
- **"KIRAIN Wrapped"** — recap tahunan ala Spotify Wrapped, shareable ke sosmed (growth channel)
- Interaksi sosial ringan (jumlah user komunitas yang pakai KIRAIN, tanpa expose data personal)
- Ringkasan berkala otomatis via WhatsApp Business API (butuh setup provider pihak ketiga)
- Shortcut power user — quick parse text natural language ("50rb makan" auto jadi transaksi)
- Siklus akademik/semester khusus (niche buat mahasiswa)
- Sync multi-device dengan UI manajemen sesi eksplisit (kalau ternyata dibutuhkan)

---

## 6. Voice & Terminology Guide

**Prinsip umum:** hindari bahasa formal/korporat di SEMUA touchpoint, termasuk yang kecil (tombol, konfirmasi, error).

| Elemen | Istilah |
|---|---|
| Tombol tambah transaksi | **Catat** |
| Tombol simpan | **Oke, Catat** |
| Halaman pengaturan | **Pengaturan Kamu** |
| Halaman profil | **Kamu** |
| Konfirmasi hapus | **Yakin nih?** |
| Fitur laporan/insight | **Rekap Kirain** / **Cerita Bulan Ini** |
| Sisa budget aman | **Zona Aman** |
| Budget udah abis/lewat | **Zona Kirain** |
| Progress budget wajib | **Progress Cukup** |

**Contoh microcopy:**
- Empty state: *"Belum ada catatan nih. Yuk mulai dari transaksi pertama, biar gak kirain-kirain lagi 👀"*
- Defisit/saldo negatif: *"Bulan ini kebablasan nih, gapapa. Yuk kita rapiin lagi bulan depan 💪"*
- Warning budget wajib belum kepenuhi: *"Eh tunggu, kebutuhan wajib bulan ini belum full nih. Yakin mau checkout?"*
- Reminder gajian: *"Gajian nih? Yuk alokasiin ke Target Nabung dulu sebelum kepake buat yang lain 💰"*
- Peringatan riba: *"Eh, ini kedengerannya kayak transaksi berbunga (riba) ya? Yuk coba dipikir ulang, atau kalau emang udah jalan, yuk kita bantu lunasin secepatnya 🙏"*
- Error koneksi: *"Yah, KIRAIN lagi susah connect nih. Coba cek internet kamu, atau tunggu bentar ya 🔌"*
- Transaksi offline queue: *"Transaksi kamu ke-antri dulu ya, nanti otomatis kesimpen begitu online lagi"*

**Format nominal:**
- Dashboard/ringkasan → disingkat ("Rp 1,5jt")
- Riwayat/detail transaksi → penuh ("Rp 1.500.000")

---

## 6.5. Prinsip Visual, Mockup & UI/UX

### Filosofi Desain Utama
**Prioritas nomor satu: kemudahan pengguna (ease of use).** Ini bukan cuma soal fitur, tapi soal *feel* — referensi desainnya adalah **kualitas polish ala Samsung One UI / Apple iOS**, bukan template generic Material Design mentah. Prinsip yang diadopsi dari filosofi desain mereka:
- **Banyak whitespace** — jangan padat/sesak, kasih ruang napas antar elemen
- **Tipografi jelas & hierarkis** — ukuran & bobot font yang membedakan info penting vs sekunder secara jelas sekali lihat
- **Animasi halus, bukan norak** — transisi antar layar/state harus terasa natural, hindari animasi berlebihan yang justru bikin app terasa lambat
- **Interaksi minim-tap** — setiap task (terutama nyatet transaksi) didesain untuk butuh tap sesedikit mungkin

### Mood/Vibe Visual
- **Playful tapi tetap terasa terpercaya** — karena ini app finance, orang butuh merasa "aman", walau tone santai. Jangan sampai playful-nya bikin app terkesan gak serius/gak bisa dipercaya buat data finansial
- **Ekspresif dengan personality** — banyak app finance itu kaku/formal secara visual; KIRAIN menang lewat karakter, bukan sekadar fungsi
- **Karakter "asisten yang approachable"** — bukan mascot komedi yang dominan. Kalau ada elemen visual maskot/ilustrasi, konsepnya harus selaras dengan persona "santai yang serius pas dibutuhkan" (lihat bagian 2), bukan sekadar lucu-lucuan tanpa substansi

### Color Palette — FINAL (dark & light mode)
Arah yang dipilih: **mint + coral**, dark mode dengan background hijau-gelap hangat (bukan hitam pekat polos). Ini kombinasi trustworthy (mint) + energi "kaget" (coral) yang paling pas sama persona "santai yang serius pas dibutuhkan". **Wajib mendukung kedua mode (dark & light) dengan kualitas yang sama** — bukan cuma dark mode yang dipoles.

| Token | Dark | Light | Fungsi |
|---|---|---|---|
| `bg` | `#0D1412` | `#F6FAF7` | Background utama |
| `surface` | `#16211D` | `#FFFFFF` | Card/permukaan komponen |
| `surface-2` | `#1E2B25` | `#EFF5F1` | Permukaan raised/hover |
| `border` | `#253630` | `#DCE6E1` | Garis pembatas card, divider |
| `text` | `#F2F5F3` | `#14201A` | Teks utama |
| `text-dim` | `#8FA39A` | `#5C6D66` | Teks sekunder/caption |
| `mint` (fill) | `#7FE0C4` | `#7FE0C4` | Background tombol/badge/progress bar — SAMA di 2 mode |
| `mint-strong` (teks/icon) | pakai `mint` langsung | `#12946E` | Versi gelap khusus teks/icon mint di atas background terang |
| `coral` (fill) | `#FF8B5E` | `#FFB08A` | Background badge/aksen Keinginan/Zona Kirain — lebih soft di light mode |
| `coral-strong` (teks/icon) | pakai `coral` langsung | `#E2613A` | Versi gelap khusus teks/icon coral di light mode |

**Prinsip kunci — "fill vs strong":**
- Warna **fill** (dipakai sebagai background elemen seperti tombol, badge, progress bar) bisa tetap sama cerahnya di kedua mode, karena selalu dipasangkan teks/icon gelap (`#0D1412`) di atasnya.
- Warna yang dipakai langsung sebagai **teks atau icon** (bukan di dalam sebuah fill, misal label kategori berwarna, angka persentase berwarna) butuh varian **`-strong`** yang lebih gelap khusus untuk light mode, supaya kontras tetap memenuhi standar aksesibilitas. Di dark mode, token dasar (`mint`/`coral`) sudah cukup kontras untuk dipakai sebagai teks langsung.
- Implementasi Flutter: definisikan sebagai custom `ColorScheme`/`ThemeExtension`, BUKAN pakai `colorSchemeSeed: Colors.teal` (default saat ini) — perlu diganti agar sesuai token di atas.

**Catatan penting soal state kritis:** pas kondisi "Zona Kirain" (defisit/budget jebol), **tetap pakai warna coral yang sama** (bukan warna merah alarm baru). Ini disengaja — supaya visualnya tetap "satu keluarga" sama Zona Aman, cuma intensitas/konteksnya beda. Menghindari red-alert generic yang kesannya menghakimi, sesuai prinsip tone suportif di bagian 2 & 6.



### Implementasi ColorScheme — WAJIB Eksplisit (bukan fromSeed)
> Ditemukan dari testing di device asli: pakai `ColorScheme.fromSeed(seedColor: ...).copyWith(...)` menghasilkan tone pastel/desaturated di slot yang TIDAK di-override manual (surface container, outline, onSurfaceVariant, dst), sehingga elemen seperti icon kategori jadi nyaris tak terlihat (mint di atas background mint pucat).

**Aturan implementasi:** definisikan `ColorScheme` secara **eksplisit lengkap** (semua field relevan: `surface`, `surfaceContainer`/`surfaceContainerHighest`, `outline`, `outlineVariant`, `onSurface`, `onSurfaceVariant`, `primary`, `onPrimary`, `secondary`, `onSecondary`, `error`, `onError`) memakai hex persis dari tabel token di atas — JANGAN mengandalkan hasil turunan algoritmis dari `fromSeed` untuk slot manapun yang terlihat di UI. Verifikasi juga bahwa `mintStrong`/`coralStrong` benar-benar dipakai untuk warna teks/icon langsung di light mode (bukan cuma didefinisikan tapi tidak di-wire).

### Liquid Glass — Elemen Visual Tambahan (ditambahkan setelah testing awal)
Terinspirasi dari kualitas polish Samsung One UI / iOS, dan konsisten dengan pattern yang sudah pernah diterapkan di GENSITI (hybrid liquid glass nav bar). Diterapkan selektif — BUKAN di semua elemen, supaya tetap performant dan tidak norak.

**Diterapkan di:**
- Bottom navigation bar
- Bottom sheet (dialog konfirmasi, filter Rekap)
- Hero card di Home (opsional, evaluasi setelah dicoba — jangan dipaksakan kalau bikin teks progress bar sulit terbaca)

**Spesifikasi teknis:**
- `BackdropFilter` dengan `ImageFilter.blur(sigmaX: 20, sigmaY: 20)` di belakang permukaan translucent
- Permukaan: `surface` dengan opacity ~0.7–0.85 (dark mode) / ~0.75–0.9 (light mode) — bukan solid
- Border tipis 1px, warna putih ~15-20% opacity (dark mode) atau hitam ~6-8% opacity (light mode), untuk kesan "tepi kaca"
- Shadow lembut di bawah elemen (bukan shadow tajam) untuk kesan mengambang/depth
- **Wajib dites kontras teks di atasnya tetap terbaca** — kalau blur+translucent bikin teks sulit dibaca di atas konten yang lewat di baliknya, turunkan opacity permukaan atau batalkan glass effect di elemen itu

### Prinsip Animasi & Transisi (ditambahkan setelah testing awal)
Perpindahan HARUS terasa halus, bukan potongan instan — ini bagian dari "kualitas polish ala Samsung/Apple" yang sudah ditetapkan sebagai filosofi desain utama.
- **Perpindahan tab bottom nav**: tambahkan transisi (fade atau fade+slide halus), jangan biarkan default `IndexedStack` yang instan tanpa animasi
- **Push/pop halaman**: gunakan `PageTransitionsTheme` yang konsisten (bisa custom, tidak harus default Android abrupt transition)
- **Perubahan state kecil** (toggle, expand accordion FAQ, progress bar terisi, dialog muncul/hilang): gunakan implicit animation widget (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedSize`, dst), jangan perubahan instan
- Durasi animasi disarankan singkat (150-300ms) — tetap terasa responsif, bukan lambat

### Kustomisasi Icon & Warna Kategori (keputusan: Opsi A, dengan migration)
User BISA memilih icon & warna sendiri saat membuat kategori custom — TAPI dari pilihan terkurasi, bukan bebas tanpa batas:
- **Icon**: grid ~20-30 icon yang relevan untuk kategori finansial (makanan, transport, rumah, hiburan, olahraga, kesehatan, hobi, dst), dikurasi manual — BUKAN seluruh library Lucide Icons yang jumlahnya ribuan. Tujuannya: user tidak kewalahan mencari, dan gaya visual tetap konsisten.
- **Warna**: preset palette terbatas (~6-8 pilihan) yang harmonis dengan brand (turunan/variasi dari mint & coral, plus beberapa warna netral pelengkap) — BUKAN color picker bebas/color wheel. Tujuannya: kategori custom tetap terasa "KIRAIN", tidak jadi rainbow yang tidak nyambung dengan palet dark/light mode yang sudah dirancang.
- Skema database: kolom `icon` (string, key/nama icon dari daftar terkurasi) dan `color` (string, hex dari preset palette) ditambahkan ke tabel `categories`, nullable — kategori default (14 bawaan) tetap pakai mapping `categoryIcon()`/`categoryIconColor()` yang sudah ada di kode (tidak perlu diisi ulang manual), kolom baru ini khusus untuk kategori custom buatan user.

### Fleksibilitas Fitur yang Perlu Dipastikan Ada
Ditemukan dari testing: user harus bisa **menambah kategori sendiri** (bukan cuma pakai 14 kategori default), baik dari:
1. Layar Kelola Kategori — tombol tambah kategori baru (nama, kind, expense type, icon, warna)
2. Layar Catat — opsi "+ Tambah kategori" di ujung salah satu grup chip kategori, sebagai shortcut tanpa harus keluar dari alur pencatatan

### Tipografi — FINAL
- **Display/heading/angka**: **Sora** (rounded, punya karakter, bawa personality "kaget" tapi tetap rapi)
- **Body text**: **Inter** (netral, gampang dibaca di ukuran kecil)

### Signature Visual Element
**"Alis kaget"** — dua lengkungan asimetris (bukan progress ring generik) yang muncul di hero card dashboard, merepresentasikan ekspresi kaget yang jadi inti nama "Kirain". Berubah warna sesuai state:
- Zona Aman → mint + coral (dua warna beda, playful)
- Zona Kirain → coral + coral, sudut lebih "tajam/curam" (lebih intens tapi tetap dalam keluarga warna yang sama)

### Visual Language Kategori (Icon & Warna)
- Tiap kategori (Makan, Transportasi, dll) punya **icon unik + warna konsisten** — icon adalah identifier utama, warna cuma pemanis. Ini penting supaya tetap bisa dibedakan oleh user buta warna (sekitar 1 dari 12 pria)
- Icon set harus **konsisten style-nya** — semua outline/rounded, jangan campur flat & 3D dalam satu set
- Kategori Wajib default pakai warna mint, kategori Keinginan default pakai warna coral (bisa di-override user kalau custom kategori)
- Kategori yang belum pernah dipakai auto-collapse dari list utama (lihat bagian 4) — bagian dari prinsip "jangan bikin UI berantakan dengan hal yang gak relevan buat user tersebut"

### Koreksi & Gap dari Kode yang Sudah Ada
> Ditemukan dari laporan struktur kode aktual (Agustus 2026). Ini bukan fitur baru, tapi PERBAIKAN dari yang sudah berjalan — prioritaskan sebelum lanjut menambah layar baru.

1. **Color scheme masih default `colorSchemeSeed: Colors.teal`** — HARUS diganti ke custom `ColorScheme`/`ThemeExtension` sesuai tabel token dark & light mode di atas. Teal itu default Flutter/Material 3, bukan keputusan desain KIRAIN.
2. **Format nominal masih penuh di semua tempat** (`Rp 1.500.000`) — di Home/Dashboard seharusnya disingkat (`Rp 1,5jt`) sesuai prinsip di bagian ini, detail/Rekap tetap format penuh (ini sudah benar).
3. **Icon kategori masih generic** (`Icons.category_outlined` untuk semua) — ganti sesuai mapping icon spesifik per kategori yang terlihat di mockup `kirain-catat-mockup.jsx` dan `kirain-categories-mockup.jsx`.

### Referensi Mockup yang Sudah Dibuat
> File-file ini dibuat sebagai referensi visual (React/HTML, BUKAN kode Flutter final) — dipakai sebagai acuan saat implementasi ulang di Flutter, bukan untuk di-port langsung. **Semua mockup di bawah ini masih dark-mode only** — light mode belum digambar secara eksplisit, tapi WAJIB diimplementasikan dengan kualitas setara memakai tabel token di atas, bukan sekadar hasil auto-invert.

> **Cara pakai referensi ini di Claude Code:** file-file `.jsx` ini dikirim LANGSUNG sebagai referensi (bukan discreenshot), karena nilai eksak (hex warna, px, border-radius, struktur layout) lebih presisi dibaca dari kode daripada gambar. Tapi ini **HANYA referensi visual React — JANGAN di-port/disalin langsung**. Reinterpretasi total pakai widget Flutter native (Column/Row/Container/dst) sesuai struktur project yang sudah ada, dengan token warna & tipografi di bagian ini sebagai acuan.

1. `kirain-home-mockup.jsx` — **Home/Dashboard (Zona Aman)**: hero card progress Wajib vs Keinginan, tips banner, list kategori dengan icon, bottom nav 4 tab dengan tombol "Catat" menonjol
2. `kirain-states-mockup.jsx` — **Zona Kirain (state kritis) + Warning dialog checkout**: variant hero card saat budget wajib jebol (tone tetap suportif), bottom sheet soft-warning saat checkout Keinginan padahal Wajib belum kepenuhi (TIDAK blocking)
3. `kirain-catat-mockup.jsx` — **Catat (quick-add)**: segmented control Transaksi/Nabung (constraint exactly-one category_id/goal_id), category chip dengan icon per kategori, toggle override Wajib/Keinginan, soft warning riba inline
4. `kirain-rekap-mockup.jsx` — **Rekap (riwayat transaksi)**: search + filter chip, list dikelompokkan per tanggal, badge "NABUNG", indikator income, indikator perbandingan periode
5. `kirain-kamu-mockup.jsx` — **Kamu (profil/hub pengaturan)**: profil minimal (email saja), toggle App Lock inline, menu terkelompok, danger zone (Keluar/Hapus Akun)
6. `kirain-onboarding-mockup.jsx` — **Onboarding**: 3 slide + tombol Lewati selalu tersedia, signature "alis kaget" sebagai elemen brand
7. `kirain-goals-mockup.jsx` — **Target Nabung**: drag-handle + nomor prioritas (priorityOrder), Dana Darurat mendapat highlight khusus (badge "DISARANKAN") saat isEmergencyFund
8. `kirain-categories-mockup.jsx` — **Kelola Kategori**: dikelompokkan Wajib/Keinginan/Pemasukan, menampilkan state budgetLimit nullable secara jujur ("Belum diset" vs nominal)
9. `kirain-recurring-mockup.jsx` — **Transaksi Berulang**: card dengan frekuensi & tanggal jatuh tempo, state nonaktif (isActive: false)
10. `kirain-budget-cycle-mockup.jsx` — **Siklus Budget**: grid pilih tanggal 1-31 (cycleStartDay), toggle rollover
11. `kirain-bantuan-mockup.jsx` — **Bantuan/FAQ**: pola accordion, 5 pertanyaan relevan fitur KIRAIN, CTA kontak WA/email
12. `kirain-legal-mockup.jsx` — **Template Legal** (dipakai utk Kebijakan Privasi & Syarat Ketentuan): intro tetap tone KIRAIN, bukan wall-of-text formal


### App Icon & Splash Screen
- App icon: simpel, warna kontras tinggi biar standout di homescreen (kebanyakan app finance pakai warna hijau/biru, jadi warna beda otomatis menonjol)
- Splash screen: logo + nama app doang, durasi singkat, animasi masuk boleh (misal fade-in) tapi jangan berlebihan

### Loading & Error States
- Loading: **skeleton screen** (bentuk kotak-kotak placeholder yang meniru layout asli) — terasa lebih modern & responsif dibanding spinner polos
- Error: pesan jelas + actionable (tombol retry), bahasa sesuai brand (lihat bagian 6), hindari jargon teknis/error code mentah

### Tone of Voice dalam Microcopy (ringkasan, detail lengkap di bagian 6)
- Notifikasi & pesan kontekstual mengikuti mood "kirain" — kaget-tapi-santai, bukan menghakimi
- Contoh empty state, warning, error — lihat bagian 6 "Voice & Terminology Guide"

### Navigasi
- Bottom navigation 4 tab: **Home / Catat / Rekap / Kamu** (lihat bagian 4)
- Tombol "Catat" (tambah transaksi) idealnya jadi elemen paling menonjol di navigasi (biasanya di tengah, sedikit lebih besar) — karena ini aksi paling sering dilakukan user

### Aksesibilitas Dasar (wajib diperhatikan sejak mockup, bukan tempelan belakangan)
- Kontras warna cukup, terutama diuji di dark mode
- Tap target minimal 48x48dp (standar Android)
- Ukuran font mengikuti setting sistem device (jangan hardcode kecil)
- Skip fitur aksesibilitas advance (screen reader optimization detail) untuk v1 — cukup ikuti best practice dasar Flutter/Material Design yang sudah built-in

---

## 7. Legal — Poin Terms of Service

1. Deskripsi layanan — KIRAIN adalah alat bantu pencatatan pribadi, BUKAN layanan finansial berlisensi/bank/e-wallet
2. Syarat akun pengguna (umur minimal, tanggung jawab keamanan login)
3. Kepemilikan data — data transaksi tetap milik user
4. Batasan tanggung jawab (disclaimer) — KIRAIN bukan penasihat keuangan resmi, bukan bertanggung jawab atas keputusan finansial user
5. Larangan penyalahgunaan (reverse engineering, aktivitas ilegal, dll)
6. Hak perubahan layanan sepihak
7. Kondisi penghentian/suspend akun
8. Kontak & penyelesaian sengketa (arahkan ke WA/email support)

---

## 8. Personal Branding

- Halaman "Tentang" di dalam app menampilkan nama developer secara personal (bukan brand korporat anonim), contoh: *"Kirain dibuat oleh Reno, developer solo yang juga lagi belajar ngatur duit sendiri 😄"*
- Opsional: link portofolio/LinkedIn/GitHub

---

## 9. Testing & Launch Plan

- **Device testing**: OPPO A3s (Android 8.1 — lower bound), device pribadi (higher-end/foldable — Galaxy Z Flip5) + emulator Android Studio buat gap versi di tengah
- **Beta testing**: grup WA kecil (5-10 orang circle Generus), fokus feedback ke 2 hal: kemudahan nyatet transaksi & kepakean toggle wajib/keinginan
- **Rating prompt**: munculin setelah milestone positif (misal 14 hari konsisten nyatet), pakai Google In-App Review API — jangan di hari pertama install
- **Testimoni**: kumpulin dari beta tester setelah 2-3 minggu pakai, izin quote (nama depan/anonim), simpan buat listing/promosi

### App Store Listing
- **Nama**: Kirain - Asisten Keuanganmu
- **Screenshot** (urutan): Dashboard progress wajib/keinginan → Quick-add → Rekap/insight bulanan → Fitur keamanan (PIN/biometric) → Dark mode
- **ASO keywords**: aplikasi keuangan, catatan pengeluaran, atur keuangan, budgeting, kelola uang, financial planner, money tracker, kebutuhan vs keinginan, asisten keuangan

---

## 10. Post-Launch Iteration Plan

**Prioritas feedback:**
1. Bug/crash → prioritas tertinggi (trust data finansial)
2. UX friction → prioritas kedua (menyerang value inti "kemudahan")
3. Feature request → dikumpulin dulu, cari pola sebelum dieksekusi

**Proses:** feedback masuk lewat WA/email → dicatat manual (Notion/Sheet) → direview & diprioritaskan pas ada waktu luang (weekend) → rilis update kecil berkala (gak perlu jadwal ketat, yang penting app terasa "hidup & diurus").

---

## 11. Hal yang Sengaja TIDAK Dimasukkan ke V1

- Multi-currency (full Rupiah dulu)
- Onboarding quiz/personality
- Voice input / scan struk otomatis / baca notifikasi bank-ewallet otomatis
- Sistem referral dengan reward (cukup tombol share sederhana)
- Analytics kompleks (kalau perlu, minimal event tracking privacy-friendly via Firebase)
- Fitur khusus siklus akademik/semester

---

*Dokumen ini adalah rangkuman brainstorming, bukan spek final yang gak bisa berubah — tetap fleksibel disesuaikan pas eksekusi berjalan.*
