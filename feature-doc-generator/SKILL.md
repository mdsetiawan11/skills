---
name: feature-doc-generator
description: Reverse-engineers documentation for existing SIIHPS/BPK application features straight from the codebase (frontend SMART repo + backend BPK.WebAPI.SIIHPS repo) and database schema — never from a fresh requirement. Use whenever the user asks to "dokumentasikan fitur X", "buat dokumentasi aplikasi", "reverse-engineer dokumentasi", asks for an ERD from an existing database, or just names a module/database/feature without saying "documentation" explicitly (e.g. "dokumentasikan SIIHPS", "buatkan ERD dari database ini", "jelasin alur fitur kinerja tematik"). Produces Lite or Full markdown docs under docs/ depending on whether the feature touches database tables, plus a cross-module ERD when asked about the database as a whole.
---

# Feature Doc Generator

Dokumentasikan fitur SIIHPS/BPK dengan cara **membaca kode yang sudah ada**, bukan menulis spec baru.
Sumber kebenaran ada tiga, dalam urutan ini: **database schema → kode (controller/service) → UI/menu**.
Kalau ketiganya nggak sinkron, jangan ditebak — catat sebagai open question di dokumen.

Repo yang relevan:
- Frontend (repo aktif, MVC + Razor, tipis, panggil API): `D:\Repository\FRONTEND\SMART`
- Backend (Web API, business logic + data access): `D:\Repository\BACKEND\SMART\WebApiGitNew`,
  project `BPK.WebAPI.SIIHPS` di dalam solution `BPK.WebAPI.sln`

Kalau lokasi backend user berbeda dari default di atas, tanya path-nya sebelum mulai scan.

## Kenapa urutan database → kode → UI

Nama menu di UI sering nggak sama dengan nama tabel/kolom asli, dan istilah yang dipakai user
(Indonesian domain terms: Satker, Eselon, LHP, IHPS, Narasi, Kinerja, Opini, Temuan, dll) kadang beda
dari nama teknis di kode. Mulai dari struktur data memberi kerangka yang paling stabil; kode
menjelaskan aturan bisnis di atas struktur itu; UI mengonfirmasi bagaimana user sebenarnya
memakainya. Kalau dibalik (mulai dari UI), gampang salah asumsi soal validasi/constraint yang
sebenarnya cuma ada di backend.

## Alur kerja

### 1. Inventory dan konfirmasi scope

Sebelum scan penuh (terutama untuk permintaan besar seperti "dokumentasikan seluruh SIIHPS"),
lakukan pass ringan dulu:
- Frontend: daftar controller di bawah `Controllers/` (termasuk subfolder `Narasi/`, `Administrasi/`,
  `Sepp7/`, `Uat/`) dan menu yang direferensikan lewat `ViewComponents/MenuViewComponent.cs`.
- Backend: daftar controller di bawah `WebAPI.SIIHPS/BPK.WebAPI.SIIHPS/Controllers/`, service di
  `BPK.WebAPI.SIIHPS.Services`, dan `DbContext`/EF Model di `BPK.WebAPI.Data/Context` dan `Models/`
  yang relevan dengan modul SIIHPS.

Tampilkan tabel ringkasan sebelum lanjut ke reverse-engineering detail:

| Fitur | Controller (FE/BE) | Nyentuh tabel DB? | Estimasi kompleksitas | Level dokumentasi |
|---|---|---|---|---|

Minta user konfirmasi prioritas/urutan dari tabel ini. **Jangan mulai scan penuh codebase/database
untuk request besar tanpa konfirmasi ini** — kalau user cuma minta satu fitur spesifik yang scope-nya
jelas, langsung boleh lanjut tanpa tabel inventory.

### 2. Tentukan level dokumentasi

Setelah tahu fitur mana yang dikerjakan, putuskan levelnya berdasarkan apa yang ditemukan di kode,
bukan tebakan:

- **Lite** — fitur tidak menulis/membaca tabel database sendiri (murni UI/kalkulasi/orkestrasi
  pemanggilan API lain), tidak butuh audit trail.
- **Full** — fitur menyentuh tabel database (insert/update/delete atau query kompleks lintas tabel),
  atau ada kebutuhan audit trail/histori.

Sinyal di kode: kalau service backend fitur itu inject `DbContext`/pakai `GenericRepository<Entity>`/
raw Dapper query untuk read-write, itu Full. Kalau service cuma agregasi dari service lain atau
transform data tanpa akses tabel sendiri, itu Lite.

### 3. Reverse-engineering per fitur

Urutan: **database dulu, lalu kode, lalu UI** — cross-check ketiganya.

**Database** (skip untuk fitur Lite):
- Cari EF entity `Models/` dan `DbContext` (`Context/`) di backend yang dipakai service fitur ini.
- Cari raw SQL/stored procedure call via Dapper (`IDbConnectionFactory`) kalau service pakai itu.
- Catat: nama tabel, kolom relevan (bukan semua kolom — cuma yang dipakai fitur ini), tipe data,
  FK ke tabel lain, constraint/index yang terlihat dari EF Fluent API atau migration kalau ada.
- **Jangan connect langsung ke database** untuk introspect schema kecuali user secara eksplisit minta
  dan mengonfirmasi — schema dari kode/EF Model/migration sudah cukup dan lebih stabil (tidak butuh
  connection string, tidak bergantung environment). Kalau info dari kode nggak cukup (misal EF Model
  nggak lengkap merepresentasikan constraint DB), baru tanya user apakah boleh connect ke DB.

**Kode**:
- Backend: controller action → service method yang dipanggil → validasi/business rule di service.
- Frontend: controller action yang manggil backend (lewat `HTTPWebRequestRepository<T>`/`IUrlApi` +
  `TypeUrl`), DTO yang dipetakan, `RoleMenu`/`IdMenu` gating kalau ada.
- Catat alur data end-to-end: request dari view → controller FE → API BE → service → DB (atau
  sebaliknya untuk read).

**UI/menu**:
- Cari view Razor terkait (`Views/<Feature>/*.cshtml`), termasuk kasus di mana controller me-render
  view di folder `Views/` yang namanya beda dari nama controllernya.
- Catat langkah pemakaian dari sudut pandang user: menu apa, form/field apa, aksi apa (CanView/
  CanEdit/CanDelete dari `RoleMenu`).

**Cross-check**: kalau nama field di DB, DTO, dan UI label beda-beda, itu normal — catat mapping-nya.
Kalau ada logic di kode yang nggak punya representasi di UI (atau sebaliknya, tombol UI yang manggil
endpoint yang sudah tidak ada), itu **bukan sesuatu yang ditebak** — tulis sebagai item di
"Open Questions/Temuan" pada dokumen Full, atau tanya user langsung untuk dokumen Lite.

### 4. Grilling session — klarifikasi role/akses ke user

Sebelum nulis dokumen, cek apakah reverse-engineering di langkah 3 menyisakan hal-hal soal **role/akses**
yang nggak bisa dijawab cuma dari kode: gating `RoleMenu`/`IdMenu` yang nggak jelas cakupannya, kombinasi
role yang boleh/tidak boleh suatu aksi, override akses (impersonation, akses satker per role), atau guard
yang keliatan tidak konsisten antar endpoint serupa (kayak satu method cek kondisi ekstra tapi method
lain yang mirip nggak). Kode cuma bilang "IdMenu X" atau "role Y bisa CanEdit" — dia nggak bilang **kenapa**
begitu atau apakah itu disengaja.

Kalau ada hal semacam itu, jangan ditebak dan jangan cuma dicatat di Open Questions lalu lanjut jalan.
Lakukan sesi tanya balik yang persisten ke user — bukan satu pertanyaan basa-basi di akhir, tapi
serangkaian pertanyaan tajam sampai ambiguitasnya benar-benar clear (semangatnya sama seperti skill
`grill-me`: interview yang nggak berhenti di jawaban pertama kalau jawabannya masih buka pertanyaan baru).

Contoh yang wajib digrill kalau ditemukan di kode:
- "Role A bisa `CanEdit` di menu ini, role B cuma `CanView` — apakah ini sesuai desain, atau harusnya B
  juga bisa edit di kondisi tertentu?"
- "Endpoint X butuh syarat tambahan (mis. file harus ada) sebelum role bisa validasi, tapi endpoint Y yang
  mirip nggak — apakah ini disengaja atau ada requirement yang belum sinkron di kode?"
- "Impersonate/akses satker override role asli user — apakah role hasil override ini yang harus dipakai di
  dokumentasi CanView/CanEdit, atau role aslinya?"

Setiap jawaban user langsung dipakai untuk mengisi bagian yang relevan di dokumen (biasanya
Functional/Non-Functional Requirements atau Technical Notes), bukan cuma ditaruh di Open Questions.
Kalau setelah digrill user bilang "itu memang belum jelas, catat aja sebagai open question" — baru boleh
masuk ke Open Questions apa adanya.

Kalau nggak ada ambiguitas role/akses yang terdeteksi, skip langkah ini dan lanjut ke langkah 5.

### 5. Tulis dokumen

Struktur folder output (default di repo frontend, `D:\Repository\FRONTEND\SMART\docs\`, kecuali user
kasih path lain):

```
docs/
├── 00-overview.md
├── 01-database/
│   ├── erd.md                  # ERD lintas modul, level overview relasi antar modul
│   └── schema-reference.md     # detail tabel per fitur yang sudah didokumentasikan
├── 02-features/
│   └── <nama-fitur>.md         # satu file per fitur, pakai Lite atau Full template
└── 03-glossary.md              # istilah domain Indonesia (Satker, Eselon, dst)
```

**Sebelum overwrite file yang sudah ada di `docs/`, konfirmasi ke user dulu** — tunjukkan apa yang
akan berubah (misal: file X sudah ada, isinya mau ditambah section Y / diganti section Z).

Template lengkap ada di `references/templates.md` — baca file itu untuk isi persis Lite Template,
Full Template, dan format `erDiagram` mermaid yang dipakai di `01-database/erd.md`.

Setelah tiap dokumen ditulis, **tampilkan ringkasan singkat** (poin-poin apa yang masuk, bukan
nge-paste ulang isi dokumen), lalu tanya: lanjut ke fitur berikutnya, atau ada koreksi dulu?

### 6. ERD permintaan langsung (tanpa dokumentasi fitur)

Kalau user cuma minta "buatkan ERD dari database SIIHPS" tanpa minta dokumentasi fitur apa pun:
- Tetap masuk ke alur ini (skill tetap trigger meski kata "dokumentasi" tidak disebut).
- Fokus langsung ke langkah database di atas, scope ke tabel-tabel yang relevan dengan modul yang
  diminta.
- Kalau tabelnya banyak, buat level overview dulu (relasi antar modul/domain, bukan setiap kolom),
  dan tulis ke `docs/01-database/erd.md`.
- Skip langkah kode/UI kecuali user juga minta konteks fitur.

## Guardrail — selalu konfirmasi dulu sebelum:

1. Scan seluruh codebase atau seluruh database untuk request besar (bukan satu fitur spesifik).
2. Overwrite dokumen yang sudah ada di `docs/`.
3. Connect langsung ke database untuk introspect schema (bukan baca dari kode/EF Model/migration).

Kalau salah satu dari tiga hal ini kepicu di tengah jalan (bukan cuma di awal), berhenti dan tanya
dulu — jangan asumsikan konfirmasi di awal percakapan berlaku untuk semua langkah berikutnya.
