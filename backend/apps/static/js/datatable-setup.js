var irigasiTable;

function fixIrigasiTable() {
    if ($.fn.DataTable.isDataTable('#irigasiTable')) {
        irigasiTable.columns.adjust();
    }
}

$(document).ready(function() {
    if ($('#irigasiTable').length > 0) {
        irigasiTable = $('#irigasiTable').DataTable({
            "pageLength": 5,
            "lengthMenu": [5, 10, 25, 50],
            "order": [[0, "asc"]],
            "autoWidth": false,
            "language": {
                "url": "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json"
            }
        });
    }
});

// =========================================================
// 1. FUNGSI LOAD TABEL SALURAN (Mengacu ke model AsetSaluran)
// =========================================================
function loadSaluranTable(diId) {
    if ($.fn.DataTable.isDataTable('#tabelSaluran')) {
        $('#tabelSaluran').DataTable().destroy();
    }

    var tableSaluranModal = $('#tabelSaluran').DataTable({
        destroy: true,
        stateSave: false,
        ajax: {
            url: `/api/daerah-irigasi/`, // Berubah ke endpoint umum
            dataSrc: function(json) {
                // 1. Cari objek DI yang ID-nya cocok dengan diId yang diklik
                // Kita asumsikan json adalah Array of Objects
                let dataDI = json.find(item => item.id == diId);
                
                if (dataDI && dataDI.saluran_list) {
                    // 2. Filter hanya saluran yang sudah approved
                    return dataDI.saluran_list.filter(item => item.is_approved === true);
                }
                return []; // Kembalikan array kosong jika tidak ketemu
            }
        },
        "dom": "<'row mb-2'<'col-md-6'l><'col-md-6 text-end'B>>" +
               "<'row'<'col-sm-12'tr>>" +
               "<'row mt-2'<'col-sm-5'i><'col-sm-7'p>>",
        "buttons": [
            { extend: 'copy', className: 'btn btn-xs btn-outline-dark', text: '<i class="fas fa-copy"></i>' },
            { extend: 'excel', className: 'btn btn-xs btn-outline-dark', text: '<i class="fas fa-file-excel"></i>' },
            { extend: 'pdf', className: 'btn btn-xs btn-outline-dark', text: '<i class="fas fa-file-pdf"></i>' },
            { extend: 'print', className: 'btn btn-xs btn-outline-dark', text: '<i class="fas fa-print"></i>' }
        ],
        scrollX: true,
        autoWidth: false,
        pageLength: 5,
        columns: [
            // 0. No
            { data: null, render: (d, t, r, meta) => meta.row + 1, className: 'text-center align-middle' },
            // 1. Nama Saluran
            { data: 'nama_saluran', className: 'align-middle fw-bold text-primary', defaultContent: '-' },
            // 2. Tingkat / Kode
            { 
                data: 'kode_aset_saluran', 
                className: 'text-center align-middle',
                render: function(data) {
                    let kode = data || '-';
                    let mapping = {'S01':'Primer','S02':'Sekunder','S15':'Tersier'};
                    return `<span class="badge border border-secondary text-secondary">${kode} - ${mapping[kode] || 'Lainnya'}</span>`;
                }
            },
            // 3. Hulu
            { 
                data: null, className: 'small align-middle',
                render: function(data, type, row) {
                    let geo = row.geometry_data || row.geom;
                    if (geo && geo.coordinates && geo.coordinates.length > 0) {
                        let startCoord = geo.type === 'LineString' ? geo.coordinates[0] : geo.coordinates[0][0];
                        if (startCoord && startCoord.length >= 2) return `<i class="fa-solid fa-circle-dot text-danger me-1"></i>${parseFloat(startCoord[0]).toFixed(5)}, ${parseFloat(startCoord[1]).toFixed(5)}`;
                    }
                    return '-';
                }
            },
            // 4. Hilir
            { 
                data: null, className: 'small align-middle',
                render: function(data, type, row) {
                    let geo = row.geometry_data || row.geom;
                    if (geo && geo.coordinates && geo.coordinates.length > 0) {
                        let endCoord = geo.type === 'LineString' ? geo.coordinates[geo.coordinates.length - 1] : geo.coordinates[geo.coordinates.length - 1][geo.coordinates[geo.coordinates.length - 1].length - 1];
                        if (endCoord && endCoord.length >= 2) return `<i class="fa-solid fa-flag-checkered text-primary me-1"></i>${parseFloat(endCoord[0]).toFixed(5)}, ${parseFloat(endCoord[1]).toFixed(5)}`;
                    }
                    return '-';
                }
            },
            // 5. Panjang
            { data: 'panjang_saluran', className: 'text-end align-middle fw-bold', render: (d) => d ? `${parseFloat(d).toLocaleString('id-ID')} m` : '0 m' },
            // 6. Luas
            { data: 'luas_layanan', className: 'text-end align-middle', defaultContent: '0 Ha' },
            
            // --- 7. LEBAR SALURAN (BARU) ---
            // { data: 'lebar_saluran', className: 'text-center align-middle', render: (d) => d ? `${d} m` : '0 m' },
            
            // --- 8. TINGGI SALURAN (BARU) ---
            // { data: 'tinggi_saluran', className: 'text-center align-middle', render: (d) => d ? `${d} m` : '0 m' },

            // 9. Kondisi
           { 
                data: null,
                className: 'text-center align-middle',
                render: function(data, type, row) {
                    let kondisiFinal = "BAIK";
                    
                    
                    if (row.segmen_list && row.segmen_list.length > 0) {
                        // Ambil semua status kondisi dari segmen
                        let daftarKondisi = row.segmen_list.map(s => s.kondisi.toUpperCase());
                        
                        if (daftarKondisi.includes("RB") || daftarKondisi.includes("RUSAK BERAT")) kondisiFinal = "R. BERAT";
                        else if (daftarKondisi.includes("RR") || daftarKondisi.includes("RUSAK RINGAN")) kondisiFinal = "R. RINGAN";
                        else if (daftarKondisi.includes("BAP")) kondisiFinal = "BAP";
                    } else {
                        // Jika segmen kosong, pakai field kondisi_aset sebagai fallback
                        kondisiFinal = row.kondisi_aset || "BAIK";
                    }

                    let badgeClass = 'bg-success';
                    let sortKey = 1; // 1 untuk BAIK

                    if (kondisiFinal.includes('RINGAN') || kondisiFinal === 'RR') { 
                        badgeClass = 'bg-warning text-dark'; 
                        kondisiFinal = 'R. RINGAN';
                        sortKey = 2; // 2 untuk RR
                    }
                    else if (kondisiFinal.includes('BERAT') || kondisiFinal === 'RB') { 
                        badgeClass = 'bg-danger'; 
                        kondisiFinal = 'R. BERAT';
                        sortKey = 3; // 3 untuk RB
                    }
                    else if (kondisiFinal.includes('BAP') || kondisiFinal === 'BELUM ADA PASANGAN') { 
                        badgeClass = 'bg-secondary'; 
                        kondisiFinal = 'BAP';
                        sortKey = 4; // 4 untuk BAP
                    }
                    else {
                        kondisiFinal = 'BAIK';
                        sortKey = 1;
                    }

                    // PERBAIKAN 3: Gunakan parameter 'type' untuk memberitahu DataTables
                    if (type === 'sort') {
                        return sortKey;
                    }
                    return `<span class="badge ${badgeClass}" style="font-size: 10px; min-width: 65px;">${kondisiFinal}</span>`;
                }
            },
            // 10. Aksi
            { 
                data: 'id', className: 'text-center align-middle',
                render: (data, type, row) => `
                    <div class="btn-group shadow-sm">
                        <button class="btn btn-xs btn-primary" onclick="filterBangunanBySaluran(${data}, '${row.nama_saluran}')"><i class="fa-solid fa-filter"></i></button>
                        <button class="btn btn-xs btn-info text-white" onclick="ambilDataDanBukaModal(${data}, ${diId})"><i class="fa-solid fa-eye"></i></button>
                    </div>`
            }
        ],
        language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json" }
    });

    // --- LOGIKA FILTER DINAMIS ---
    $('#filterKodeSaluranModal').off('change').on('change', function() {
        tableSaluranModal.column(2).search($(this).val()).draw();
    });

    // PENTING: Index filter kondisi berubah jadi 9 karena ada sisipan kolom Lebar & Tinggi
    $('#filterKondisiSaluranModal').off('change').on('change', function() {
        tableSaluranModal.column(9).search($(this).val()).draw();
    });
}


/** * Fungsi helper untuk membersihkan format teks nomenklatur
 */
function cleanNomenklatur(data) {
    if (!data || data === '-') return '-';
    let text = data.trim();
    if (text.startsWith('- (')) {
        text = text.replace('- (', '').replace(')', '').trim();
    } else if (text.startsWith('- ')) {
        text = text.replace('- ', '').trim();
    }
    return text;
}

// Fungsi Dummy untuk Tombol Rekap
function rekapAset() { window.alert("Mencetak Rekapitulasi Kinerja & Aset..."); }
function iksiGabungan() { window.alert("Menghitung IKSI Gabungan..."); }

// Placeholder untuk fungsi tombol rekap (bisa diarahkan ke print PDF e-PAKSI)
function cetakRekapAset() { alert("Membuka Rekapitulasi Kinerja & Aset..."); }
function cetakIksiGabungan() { alert("Membuka IKSI Gabungan..."); }


// =========================================================
// LOAD TABEL BANGUNAN (VERSI FIX CLICK EVENT)
// =========================================================
// Variable global untuk menyimpan instance DataTable
var     Instance = null;

window.dataAsetGlobal = [];

// =========================================================
// LOAD TABEL BANGUNAN (KOLOM BARU)
// =========================================================
var tableBangunanInstance = null;

function loadBangunanTable(diId, saluranId = null, namaSaluran = null) {
    if ($.fn.DataTable.isDataTable('#tabelBangunan')) {
        $('#tabelBangunan').DataTable().clear().destroy();
    }

    let apiUrl = `/api/bangunan/${diId}/`;
    if (saluranId) apiUrl += `?saluran_id=${saluranId}`;

    var tableBangunan = $('#tabelBangunan').DataTable({
        "pageLength": 10,
        "lengthMenu": [[5, 10, 25, 50], [5, 10, 25, 50]],
        
        // 1. TAMBAHKAN FITUR EXPORT
        "dom": "<'row mb-2'<'col-md-6'l><'col-md-6 text-end'B>>" +
               "<'row'<'col-sm-12'tr>>" +
               "<'row mt-2'<'col-sm-5'i><'col-sm-7'p>>",
        "buttons": [
            { extend: 'copy', className: 'btn btn-xs btn-outline-dark' },
            { extend: 'excel', className: 'btn btn-xs btn-outline-dark' },
            { extend: 'pdf', className: 'btn btn-xs btn-outline-dark' },
            { extend: 'print', className: 'btn btn-xs btn-outline-dark' }
        ],

        // 4. ORDER LIST: Kode Aset (Index 2) ASC, Kondisi (Index 8) ASC (BAIK duluan)
        "order": [[2, "asc"], [8, "asc"]],

        "ajax": {
            "url": apiUrl,
            "dataSrc": function(json) {
                window.currentBangunanData = json.data;
                return json.data;
            }
        },
        "scrollX": true,
        "autoWidth": false,
        "columns": [
            { "data": null, "className": "text-center", "render": (d, t, r, meta) => meta.row + 1 },
            { 
                "data": "nomenklatur_ruas", 
                "className": "fw-bold text-primary",
                "render": (data, type, row) => data || row.nama_aset_manual || "-"
            },
            { 
                "data": "kode_aset_display", 
                "className": "text-center",
                "render": function(data, type, row) {
                    let val = data || row.kode_aset || '-';
                    return `<span class="badge border border-secondary text-secondary">${val}</span>`;
                }
            },
            { 
                "data": null, 
                "className": "text-center",
                "render": (data, type, row) => (!row.latitude || row.latitude == 0) ? 
                    '<span class="badge bg-secondary">No GPS</span>' : 
                    `<span class="small text-muted">${row.longitude.toFixed(5)}, ${row.latitude.toFixed(5)}</span>`
            },
            { "data": "nama_di", "defaultContent": "-" },
            { "data": "nama_saluran", "defaultContent": "-" }, // Index 5 untuk Filter
            { "data": "surveyor", "defaultContent": "-" },
            { 
                "data": "luas_areal", 
                "className": "text-center fw-bold",
                "render": d => d ? parseFloat(d).toLocaleString('id-ID') : '0'
            },
            { 
                "data": "kondisi_bangunan", 
                "className": "text-center", // Index 8 untuk Filter
                "render": function(data, type, row) {
                    let k = (data || row.kondisi_aset || 'BAIK').toUpperCase();
                    
                    let badgeClass = 'bg-success';
                    let labelTeks = 'BAIK';
                    let sortKey = 1; // Angka 1 untuk BAIK

                    // Penentuan Warna, Teks, dan Urutan
                    if (k.includes('RR') || k.includes('RINGAN')) { 
                        badgeClass = 'bg-warning text-dark'; 
                        labelTeks = 'R. RINGAN';
                        sortKey = 2; // Angka 2 untuk RUSAK RINGAN
                    } 
                    else if (k.includes('RB') || k.includes('BERAT')) { 
                        badgeClass = 'bg-danger'; 
                        labelTeks = 'R. BERAT';
                        sortKey = 3; // Angka 3 untuk RUSAK BERAT
                    }
                    else if (k.includes('BAP') || k.includes('PASANGAN')) {
                        badgeClass = 'bg-secondary';
                        labelTeks = 'BAP';
                        sortKey = 4; // Angka 4 untuk BAP
                    }
                    else {
                        badgeClass = 'bg-success';
                        labelTeks = 'BAIK';
                        sortKey = 1;
                    }

                    // --- JIKA DATATABLES MEMINTA DATA UNTUK DIURUTKAN (SORT) ---
                    if (type === 'sort') {
                        return sortKey;
                    }

                    // --- JIKA DATATABLES MEMINTA DATA UNTUK DITAMPILKAN (DISPLAY) ---
                    return `<span class="badge ${badgeClass}" style="font-size: 10px; min-width: 65px;">${labelTeks}</span>`;
                }
            },
            { 
                "data": null, 
                "className": "text-center",
                "render": (data, type, row) => `<button class="btn btn-xs btn-info text-white shadow-sm" onclick="showDetailPaiIksi(${row.id}, '${row.nomenklatur_ruas}')"><i class="fa-solid fa-eye me-1"></i>Detail</button>`
            }
        ],
        "language": { "url": "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json" },
        "initComplete": function () {
            var api = this.api();
            // Isi otomatis dropdown Filter Saluran dari data yang ada di tabel
            $('#filterSaluranModalBangunan').html('<option value="">-- Filter Semua Saluran --</option>');
            api.column(5).data().unique().sort().each(function (d) {
                if(d && d !== '-') $('#filterSaluranModalBangunan').append(`<option value="${d}">${d}</option>`);
            });
        }
    });

    // 2. LOGIKA FILTER SALURAN
    $('#filterSaluranModalBangunan').on('change', function() {
        tableBangunan.column(5).search($(this).val()).draw();
    });

    // 3. LOGIKA FILTER KONDISI
    $('#filterKondisiModalBangunan').on('change', function() {
        tableBangunan.column(8).search($(this).val()).draw();
    });
}


    function formatChildRow(mapId, d) {
        return '<div class="slider">' +
            '<table class="table table-sm border-0">' +
            '<tr><td class="fw-bold"><i class="fa-solid fa-map-location-dot me-2"></i>Preview Lokasi: ' + d.nomenklatur_ruas + '</td></tr>' +
            '<tr><td><div id="' + mapId + '" style="height: 50vh; width: 100%; border-radius: 8px;"></div></td></tr>' +
            '</table>' +
            '</div>';
    }

    function initChildMap(mapId, data) {
        console.log("=== DEBUG DATA BANGUNAN ===", data);
        
        var targetNamaSaluran = data.nama_saluran;
        
        // 1. Ambil Nilai Mentah
        var rawLat = parseFloat(data.latitude);
        var rawLng = parseFloat(data.longitude);

        // 2. LOGIKA ANTI-TERBALIK & ANTI-NOL
        var fixLat = 0;
        var fixLng = 0;

        // Jika koordinat mengandung angka 108, pasti itu Longitude (bukan Latitude)
        if (Math.abs(rawLat) > 90) { 
            // Berarti terbalik: Lat diisi angka 108, Lng diisi angka -6
            fixLat = rawLng;
            fixLng = rawLat;
            console.warn("🔄 Koordinat terdeteksi TERBALIK, otomatis diperbaiki.");
        } else {
            fixLat = rawLat;
            fixLng = rawLng;
        }

        setTimeout(function() {
            try {
                var container = L.DomUtil.get(mapId);
                if (container !== null) { container._leaflet_id = null; }

                // Center ke koordinat jika ada, jika tidak ke default Ciwado
                var centerPeta = (fixLat !== 0) ? [fixLat, fixLng] : [-6.826, 108.604];
                var map = L.map(mapId).setView(centerPeta, 17); // Zoom lebih dalam
                
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

                // 3. GAMBAR MARKER (Hanya jika bukan 0.0)
                // --- GAMBAR MARKER DENGAN POPUP RAPI ---
                if (fixLat !== 0) {
                    const statusWarna = (data.pintu_baik > 0) ? '#198754' : '#dc3545';
                    const statusTeks = (data.pintu_baik > 0) ? 'BAIK' : 'PERLU PERBAIKAN';

                    var epaksiIcon = L.icon({
                        iconUrl: `/static/icons/${data.kode_aset || 'default'}.png`,
                        iconSize: [35, 35],       // Ukuran icon (pixel)
                        iconAnchor: [17, 17],     // Titik tumpu di tengah icon
                        popupAnchor: [0, -15],    // Popup muncul sedikit di atas icon
                        className: 'marker-bounce' // Optional: jika ingin ditambah animasi CSS
                    });

                    L.marker([fixLat, fixLng], { icon: epaksiIcon }).addTo(map)
                        .bindPopup(`
                            <div style="width: auto; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333;">
                                <div style="background-color: #f8f9fa; padding: 10px; border-radius: 8px 8px 0 0; border-bottom: 2px solid #eee; text-align: center;">
                                    <div style="font-weight: bold; color: #0d3b66; border-bottom: 1px solid #ddd; padding-bottom: 5px; mb-2;">
                                        ${data.nomenklatur_ruas}
                                    </div>
                                    <div style="padding: 8px 0;">
                                        <img src="/static/icons/${data.kode_aset}.png" width="40" onerror="this.style.display='none'"><br>
                                        <small style="color: #666;">ID: ${data.kode_aset || '-'}</small>
                                    </div>
                                </div>

                                <div style="padding: 12px 5px;">
                                    <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
                                        <tr style="border-bottom: 1px solid #f1f1f1;">
                                            <td style="padding: 6px 0; color: #666; width: 40%;">Jenis Aset</td>
                                            <td style="padding: 6px 0; font-weight: 600; text-align: right;">${data.nama_aset_manual || '-'}</td>
                                        </tr>
                                        <tr style="border-bottom: 1px solid #f1f1f1;">
                                            <td style="padding: 6px 0; color: #666;">Tipe Pintu</td>
                                            <td style="padding: 6px 0; font-weight: 600; text-align: right;">${data.nama_jenis_pintu || '-'} (${data.pintu_total_unit} Unit)</td>
                                        </tr>
                                        <tr style="border-bottom: 1px solid #f1f1f1;">
                                            <td style="padding: 6px 0; color: #666;">Luas Areal</td>
                                            <td style="padding: 6px 0; font-weight: 600; text-align: right;">${data.luas_areal} Ha</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 6px 0; color: #666; vertical-align: top;">Lokasi</td>
                                            <td style="padding: 6px 0; font-weight: 600; text-align: right; line-height: 1.3;">
                                                Desa ${data.desa || '-'}<br>
                                                <span style="font-size: 10px; color: #999;">Kec. ${data.kecamatan || '-'}</span>
                                            </td>
                                        </tr>
                                    </table>
                                </div>

                                <div style="margin-top: 5px; display: flex; flex-direction: column; gap: 8px;">
                                    <div style="background-color: ${statusWarna}; color: white; text-align: center; padding: 4px; border-radius: 4px; font-size: 10px; font-weight: bold; letter-spacing: 1px;">
                                        ${statusTeks}
                                    </div>
                                    
                                    <a href="https://www.google.com/maps?q=${fixLat},${fixLng}" target="_blank" 
                                    style="text-decoration: none; background-color: #0d6efd; color: white; text-align: center; padding: 8px; border-radius: 6px; font-size: 11px; font-weight: 600; transition: 0.3s;">
                                    <i class="fas fa-directions"></i> PETUNJUK ARAH KE LOKASI
                                    </a>
                                </div>
                            </div>
                        `, { maxWidth: 300, className: 'custom-popup-style' })
                        .openPopup();
                }

                // 4. GAMBAR GARIS SALURAN (Garis Biru Putus-Putus)
                let targetSal = null;
                Object.values(diDataMap).forEach(di => {
                    if (di.saluran_list) {
                        const found = di.saluran_list.find(s => s.nama_saluran === targetNamaSaluran);
                        if (found) targetSal = found;
                    }
                });

                if (targetSal && targetSal.geometry_data) {
                    var layerSaluran = L.geoJSON(targetSal.geometry_data, {
                        style: { 
                            color: "#007bff", 
                            weight: 6, 
                            opacity: 0.8,
                            dashArray: (targetSal.id == 47) ? "0" : "10, 15" 
                        }
                    }).addTo(map);

                    // Jika GPS Nol, fokus ke garis saja
                    if (fixLat === 0) {
                        map.fitBounds(layerSaluran.getBounds(), { padding: [30, 30] });
                    }
                }

                map.invalidateSize();
            } catch (e) { console.error("Error Leaflet:", e); }
        }, 500);
    }

// FUNGSI RENDER PETA PER BARIS
function renderMapInRow(elemId, lat, lng, title) {
    if (typeof L === 'undefined') { alert("Leaflet JS belum di-load!"); return; }
    
    // Inisialisasi Map
    var map = L.map(elemId).setView([lat, lng], 17);
    
    var myIcon = L.icon({
        iconUrl: `/static/icons/${kodeAset || 'default'}.png`,
        iconSize: [30, 30],
        iconAnchor: [15, 15]
    });

    L.tileLayer('https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',{ 
        maxZoom: 20, 
        subdomains:['mt0','mt1','mt2','mt3'] 
    }).addTo(map);
    
    // Marker
    L.marker([lat, lng], { icon: myIcon }).addTo(map)
        .bindPopup(`<b>${title}</b><br>Lat: ${lat}<br>Long: ${lng}`)
        .openPopup();
    
    // Fix layout abu-abu
    setTimeout(function(){ map.invalidateSize(); }, 300);
}

var miniMap = null;
var currentMarker = null;

// FUNGSI 1: INISIALISASI PETA (Panggil ini sekali saat halaman dimuat)
function initMiniMap() {
    // Cek apakah Leaflet (L) sudah di-load
    if (typeof L === 'undefined') {
        console.error("Leaflet JS belum di-load!");
        return;
    }

    // Default view (Misal: Cirebon)
    if (!miniMap) {
        miniMap = L.map('miniMap').setView([-6.7320, 108.5523], 10); 
        
        // Gunakan OpenStreetMap atau Ganti dengan Tile Layer Google Bapak
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(miniMap);
    }
}

// FUNGSI 2: UPDATE LOKASI PETA (Dipanggil saat tombol koordinat diklik)
function focusKePeta(lat, lng, namaBangunan) {
    if (!miniMap) initMiniMap();

    // Validasi Koordinat
    if (!lat || !lng || lat == 0 || lng == 0) {
        alert("Koordinat tidak valid (0,0) atau kosong.");
        return;
    }

    // Hapus marker lama jika ada
    if (currentMarker) miniMap.removeLayer(currentMarker);

    // Tambah marker baru
    currentMarker = L.marker([lat, lng]).addTo(miniMap)
        .bindPopup(`<b>${namaBangunan}</b><br>Lat: ${lat}<br>Long: ${lng}`)
        .openPopup();

    // Fokuskan peta
    miniMap.setView([lat, lng], 17); // Zoom level 17 (Dekat)
    
    // Scroll layar ke arah peta agar user sadar peta berubah
    document.getElementById('miniMap').scrollIntoView({ behavior: 'smooth', block: 'center' });
}

// =========================================================
// 3. FUNGSI NAVIGASI & FILTER
// =========================================================
function filterBangunanBySaluran(saluranId, namaSaluran) {
    window.currentFilterSaluran = namaSaluran;
    window.currentFilterId = saluranId;
    const tabEl = document.querySelector('#modal-bangunan-tab');
    new bootstrap.Tab(tabEl).show();
    $('#filter-info-bangunan').html(`
        <span class="badge bg-primary px-3 py-2">
            <i class="fa-solid fa-filter me-2"></i>Saluran: ${namaSaluran}
            <i class="fa-solid fa-xmark ms-2 cursor-pointer" onclick="clearBangunanFilter($('#id_di_aktif').val())" title="Hapus Filter"></i>
        </span>
    `);
    const diId = $('#id_di_aktif').val();
    loadBangunanTable(diId, saluranId, namaSaluran);
}

function clearBangunanFilter(diId) {
    window.currentFilterSaluran = null;
    window.currentFilterId = null;

    // Reset Label UI
    $('#filter-info-bangunan').html('<span class="text-muted small italic">Menampilkan Semua Bangunan</span>');

    loadBangunanTable(diId);
}


// 3. TRIGGER TAB (DIPERBAIKI)
$(document).ready(function() {
    // Tab Saluran
    $('button[id="modal-saluran-tab"]').on('shown.bs.tab', function () {
        const diId = $('#id_di_aktif').val(); 
        if(diId) loadSaluranTable(diId);
    });

    // Tab Bangunan
    $('#modal-bangunan-tab').on('shown.bs.tab', function () {
        const diId = $('#id_di_aktif').val();
        // Cek apakah ada filter "titipan" dari klik sebelumnya
        if (window.currentFilterSaluran) {
            loadBangunanTable(diId, window.currentFilterId, window.currentFilterSaluran);
        } else {
            // Jika tidak ada filter, cek apakah tabel sudah terisi. Jika belum, baru load.
            if (!$.fn.DataTable.isDataTable('#tabelBangunan')) {
                loadBangunanTable(diId);
            }
        }
    });
});

function pindahKeBangunan(saluranId, namaSaluran) {
    filterBangunanBySaluran(saluranId, namaSaluran);
}

$(document).on("click", ".view-detail", function() {
    const el = $(this);
    let diId = el.data('id'); 
    let diData;

    try {
        diData = JSON.parse(rawData);
    } catch (e) {
        console.error("Gagal memproses JSON:", e);
        // Fallback: Jika gagal parse, coba pakai .data() bawaan
        diData = el.data('json'); 
    }

    // CEK VALIDASI: Jika masih undefined, hentikan fungsi agar tidak error merah
    if (!diData) {
        console.error("Error: Data irigasi tidak ditemukan untuk ID " + diId);
        return; 
    }
    $('#id_di_aktif').val(diId);

    const d = {
        nama: el.data('nama') || "-",
        sumber: el.data('sumber') || "-",
        bendung: el.data('bendung') || "-",
        permen: el.data('permen') || 0,
        onemap: el.data('onemap') || 0,
        // Data Chart
        p_baik: parseFloat(el.data('p_baik')) || 0,
        p_rr: parseFloat(el.data('p_rr')) || 0,
        p_rb: parseFloat(el.data('p_rb')) || 0,
        p_napas: parseFloat(el.data('p_napas')) || 0,
        s_baik: parseFloat(el.data('s_baik')) || 0,
        s_rr: parseFloat(el.data('s_rr')) || 0,
        s_rb: parseFloat(el.data('s_rb')) || 0,
        s_napas: parseFloat(el.data('s_napas')) || 0,
        pt_baik: parseFloat(el.data('pt_baik')) || 0,
        pt_rr: parseFloat(el.data('pt_rr')) || 0,
        pt_rb: parseFloat(el.data('pt_rb')) || 0
    };
 

        // Update UI
        $('#modalNama').text(diData.nama_di || "-");
        $('#modalSumber').text(': ' + (diData.sumber_air || "-"));
        $('#modalBendung').text(': ' + (diData.bendung || "-"));
        $('#modalPermen').text(diData.luas_baku_permen || 0);
        $('#modalOnemap').text(diData.luas_baku_onemap || 0);
        $('#titleIrigasi').text('Detail: ' + (diData.nama_di || ""));

        // 3. Update Summary Inventory (Sesuaikan dengan Key API)
        $('#countPrimer').text((diData.panjang_primer || 0) + " m");
        $('#countSekunder').text((diData.panjang_sekunder || 0) + " m");
        
        let totalSal = (parseFloat(diData.panjang_primer) || 0) + (parseFloat(diData.panjang_sekunder) || 0);
        $('#countTotalSal').text(totalSal);
        $('#countPintu').text((diData.jumlah_pintu || 0) + " Unit");

        // 4. Hitung Jumlah Bangunan via API Bangunan secara dinamis
        fetch(`/api/bangunan/${diId}/`)
            .then(res => res.json())
            .then(response => {
                if (response.data) {
                    $('#countBangunan').text(response.data.length); 
                }
            });

        // 5. Jalankan Fungsi Tabel & Chart
        if (typeof loadSaluranTable === "function") loadSaluranTable(diId);
        if (typeof loadBangunanTable === "function") loadBangunanTable(diId);
    

        // Animasi Overlay
        window.isAnimating = true;
        gsap.to("#detailOverlay", { 
            duration: 0.4, display: "flex", opacity: 1, ease: "power2.out",
            onComplete: function() {
                // Kita bungkus data untuk Chart
                const chartData = {
                    p_baik: diData.primer_baik || 0,
                    p_rr: diData.primer_rr || 0,
                    p_rb: diData.primer_rb || 0,
                    pt_baik: diData.pintu_baik || 0,
                    pt_rr: diData.pintu_rr || 0,
                    pt_rb: diData.pintu_rb || 0
                };
                renderModalCharts(chartData);
            }
        });
        $("#modalBackdrop").fadeIn(300);

        // 6. Load Peta (GeoJSON)
        const geojsonRaw = diData.geojson; // Ambil langsung dari JSON
        if (geojsonRaw) {
            fetch(geojsonRaw).then(res => res.json()).then(data => {
                initDetailMap(data); 
                // Pastikan fungsi ini menggunakan icon ePAKSI tadi
                renderMarkerBangunan(diId); 
            }).catch(err => console.error("Gagal load peta:", err));
        }
});

    $("#closeOverlay").on("click", function() {
        gsap.to("#detailOverlay", { 
            duration: 0.3, opacity: 0, display: "none",
            onComplete: function() {
                window.isAnimating = false;
            }
        });
        $("#modalBackdrop").fadeOut(300);
    });
