// static/admin/js/bangunan_logic.js
// document.addEventListener('DOMContentLoaded', function() {
//     const fieldDI = document.querySelector('#id_daerah_irigasi');
//     const fieldSaluran = document.querySelector('#id_saluran');

//     if (fieldDI && fieldSaluran) {
//         // Jika Daerah Irigasi diubah
//         fieldDI.addEventListener('change', function() {
//             if (this.value) {
//                 fieldSaluran.value = ""; // Set Saluran ke ---------
//             }
//         });

//         // Jika Saluran diubah
//         fieldSaluran.addEventListener('change', function() {
//             if (this.value) {
//                 fieldDI.value = ""; // Set DI ke ---------
//             }
//         });
//     }
// });

document.addEventListener('change', function(e) {
    // Mengecek apakah yang diubah adalah dropdown Poligon Layanan (pada form inline)
    if (e.target && e.target.id.endsWith('-poligon_layanan')) {
        const layerId = e.target.value;
        
        // Cari elemen pembungkus terdekat (biasanya fieldset atau div.form-row)
        const container = e.target.closest('fieldset') || e.target.closest('.form-row');
        
        // Cari input Luas Areal yang spesifik di dalam pembungkus yang sama
        const luasInput = container.querySelector('input[id$="-luas_areal"]');

        if (layerId) {
            // Panggil API yang baru saja kita buat
            fetch(`/admin/apps/bangunan/get-poligon-luas/${layerId}/`)
                .then(response => response.json())
                .then(data => {
                    if (luasInput && data.luas_areal !== undefined) {
                        luasInput.value = data.luas_areal;
                        
                        // Opsional: Beri efek visual singkat agar admin tahu data berubah otomatis
                        luasInput.style.backgroundColor = '#d4edda'; // Warna hijau muda
                        setTimeout(() => { luasInput.style.backgroundColor = ''; }, 1500);
                        
                        console.log(`Luas diupdate otomatis: ${data.luas_areal} Ha`);
                    }
                })
                .catch(err => console.error("Gagal mengambil data luas poligon:", err));
        } else {
            // Jika dropdown di-clear/dikosongkan, kembalikan ke 0
            if (luasInput) luasInput.value = 0;
        }
    }
});

document.addEventListener('change', function(e) {
    if (e.target.id === 'id_daerah_irigasi') { // Sesuaikan ID dropdown DI
        const diId = e.target.value;
        if (diId) {
            fetch(`/get-di-stats/${diId}/`)
                .then(response => response.json())
                .then(data => {
                    // Isi field luas fungsional secara otomatis
                    const luasField = document.querySelector('#id_luas_fungsional');
                    if (luasField) luasField.value = data.total_luas;
                });
        }
    }
});

document.addEventListener('change', function(e) {
    // Cek apakah yang diubah adalah dropdown Kode Aset
    if (e.target && e.target.name && e.target.name.includes('kode_aset')) {
        const kode = e.target.value;
        // Cari input Nama Aset yang satu baris dengan dropdown ini
        const row = e.target.closest('.form-row') || e.target.closest('fieldset');
        const namaInput = row.querySelector('input[name*="nama_aset_manual"]');


        const kamusAset = {
        // --- BANGUNAN UTAMA & PENGATUR (B & P) ---
        'B01': 'Bendung',
        'B02': 'Bendung Gerak',
        'B03': 'Bendung Karet',
        'B04': 'Pengambilan Bebas',
        'B05': 'Pompa',
        'B06': 'Waduk / Embung',
        'B07': 'Kantong Lumpur',
        'P01': 'Bangunan Bagi',
        'P02': 'Bangunan Bagi Sadap',
        'P03': 'Bangunan Sadap',
        'P04': 'Bangunan Pengatur',

        // --- SALURAN (S) ---
        'S01': 'Saluran Primer',
        'S02': 'Saluran Sekunder',
        'S03': 'Saluran Suplesi',
        'S04': 'Saluran Muka',
        'S11': 'Saluran Pembuang',
        'S12': 'Saluran Gendong',
        'S13': 'Saluran Pengelak Banjir',
        'S15': 'Saluran Tersier',
        'S16': 'Saluran Kuarter',
        'S17': 'Saluran Pembuang (Tersier)',

        // --- BANGUNAN PENGUKUR & PELENGKAP (C, K, D, dsb) ---
        'C01': 'Alat Ukur Ambang Lebar',
        'C02': 'Alat Ukur Parshall Flume',
        'C03': 'Alat Ukur Cipoletti',
        'C04': 'Alat Ukur Thompson',
        'C05': 'Alat Ukur Romijn',
        'K01': 'Bangunan Terjun',
        'K02': 'Got Miring',
        'K03': 'Siphon',
        'K04': 'Talud',
        'K05': 'Flume',
        'K06': 'Terowongan',
        'D01': 'Pintu Air',
        'D02': 'Pintu Sorong',
        'D03': 'Pintu Klep',
        'L01': 'Jembatan',
        'L02': 'Gorong-gorong',
        'L03': 'Bangunan Cuci / Mandi',
        'L04': 'Tempat Menyeberang Ternak',
        'L05': 'Tangga Manusia'
    };

        if (namaInput && kamusAset[kode]) {
            namaInput.value = kamusAset[kode];
        }
    }
});