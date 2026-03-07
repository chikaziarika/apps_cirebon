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

    $('#tabelSaluran').DataTable({
        destroy: true,       // Memaksa hancurkan instance lama
        stateSave: false,
        ajax: {
            url: `/api/saluran/${diId}/`,
            dataSrc: 'data'
        },
        scrollX: true,
        autoWidth: false,
        columns: [
            // 1. No
            { data: null, render: (d, t, r, meta) => meta.row + 1, className: 'text-center' },
            
            // 2. Nama Saluran
            { 
                data: 'nama_saluran', 
                render: function(data, type, row) {
                    let iconSaluran = (row.jaringan_tingkat === 'PRIMER') ? 'S01' : 'S02';
                    
                    // Gunakan template literal yang bersih
                    let imgPath = "/static/icons/" + iconSaluran + ".png"; 
                    
                    console.log("Mencari icon di:", imgPath); // Cek di console F12 browser munculnya apa

                    return `
                        <div class="d-flex align-items-center">
                            <img src="${imgPath}" 
                                width="20" 
                                height="20" 
                                class="me-2" 
                                style="object-fit: contain;"
                                onerror="console.log('Gagal load:', this.src); this.style.display='none'">
                            <a href="javascript:void(0)" 
                                onclick="filterBangunanBySaluran(${row.id}, '${data}')" 
                                class="fw-bold text-primary text-decoration-none">
                                ${data}
                            </a>
                        </div>`;
                }
            },
            
            // 3. Tingkat
            { data: 'jaringan_tingkat', className: 'text-center', defaultContent: '-' },
            
            // 4. Bangunan Hulu (DENGAN ICON)
            { 
                data: 'bangunan_hulu_nama', 
                className: 'small', 
                defaultContent: '-',
                render: function(data, type, row) {
                    if(!data || data === '-') return '-';
                    // Gunakan kode aset dari row jika ada, kalau tidak ada biarkan kosong
                    let kodeAset = row.bangunan_hulu_kode || ''; 
                    return `
                        <div class="d-flex align-items-center">
                            ${kodeAset ? `<img src="/static/icons/${kodeAset}.png" width="18" class="me-2" onerror="this.style.display='none'">` : ''}
                            <span>${data}</span>
                        </div>`;
                }
            },
            
            // 5. Bangunan Hilir (DENGAN ICON)
            { 
                data: 'bangunan_hilir_otomatis', 
                className: 'small', 
                defaultContent: '-',
                render: function(data, type, row) {
                    if(!data || data === '-') return '-';
                    let kodeAset = row.bangunan_hilir_kode || ''; // Pastikan field ini ada di API Bapak
                    return `
                        <div class="d-flex align-items-center">
                            ${kodeAset ? `<img src="/static/icons/${kodeAset}.png" width="18" class="me-2" onerror="this.style.display='none'">` : ''}
                            <span>${data}</span>
                        </div>`;
                }
            },
            
            // 6. Panjang (m)
            { 
                data: 'panjang_saluran', 
                render: d => d ? `<strong>${parseFloat(d).toLocaleString('id-ID')}</strong>` : '0',
                className: 'text-end' 
            },
            
            // 7. Luas (Ha)
            { 
                data: 'areal_fungsional', 
                render: d => d ? `<strong>${parseFloat(d).toLocaleString('id-ID')}</strong>` : '0',
                className: 'text-end' 
            },
            
            // 8. Kondisi (Mapping 'kinerja_individu')
            { 
                data: 'kinerja_individu', 
                className: 'text-center',
                render: d => {
                    const statusMap = { 'B': 'BAIK', 'RR': 'RUSAK RINGAN', 'RS': 'RUSAK SEDANG', 'RB': 'RUSAK BERAT' };
                    const colorMap = { 'B': 'success', 'RR': 'warning text-dark', 'RS': 'orange', 'RB': 'danger' };
                    const label = statusMap[d] || 'BAIK';
                    const color = colorMap[d] || 'success';
                    return `<span class="badge bg-${color}" style="font-size: 10px;">${label}</span>`;
                }
            },
            
            // 9. Aksi
            { 
                data: null, 
                className: 'text-center',
                render: (data, type, row) => {
                    return `<button class="btn btn-xs btn-outline-info" onclick="showDetailSaluran(${row.id})">
                                <i class="fa-solid fa-magnifying-glass"></i>
                            </button>`;
                }
            }
        ],
        language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json" },
        drawCallback: function() {
            $(this).DataTable().columns.adjust();
        }
    });
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

function loadBangunanTable(diId, saluranId = null, namaSaluran = null) {
    if ($.fn.DataTable.isDataTable('#tabelBangunan')) {
        $('#tabelBangunan').DataTable().clear().destroy();
    }

    let apiUrl = `/api/bangunan/${diId}/`;
    if (saluranId) apiUrl += `?saluran_id=${saluranId}`;

    // PERBAIKAN: Gunakan variabel tableBangunanInstance secara konsisten
    tableBangunanInstance = $('#tabelBangunan').DataTable({
        "pageLength": 5,
        "lengthMenu": [[5, 10, 25], [5, 10, 25]],
        "ordering": false,
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
            {
                "className": 'dt-control',
                "orderable": false,
                "data": "kode_aset", // Ambil data dari field kode_aset
                "defaultContent": '',
                "render": function (data, type, row) {
                    // Gunakan kode_aset (misal: B01, P01) untuk memanggil gambar
                    // Jika kode_aset kosong atau '0', kita pakai icon default
                    let iconTarget = (data && data !== '0') ? data : 'default';
                    
                    return `
                        <button class="btn btn-link p-0 btn-toggle-map" title="Klik untuk lihat peta">
                            <img src="/static/icons/${iconTarget}.png" 
                                width="28" 
                                class="img-thumbnail border-primary shadow-sm"
                                onerror="this.src='/static/icons/default.png'; this.onerror=null;">
                        </button>`;
                }
            },
            { "data": "nomenklatur_ruas", "defaultContent": "-" },
            { "data": "nama_saluran", "defaultContent": "-" },
            { 
                "data": null, 
                "className": "text-center",
                "render": function(data, type, row) {
                    if(!row.latitude || row.latitude == 0) return '<span class="badge bg-secondary">No GPS</span>';
                    return `<span class="small text-muted">${row.latitude.toFixed(5)}, ${row.longitude.toFixed(5)}</span>`;
                }
            },
            { "data": "kecamatan", "defaultContent": "-" },
            { "data": "desa", "defaultContent": "-" },
            { 
                "data": null,
                "render": d => (d.kode_aset && d.kode_aset !== '0') ? `<b>${d.kode_aset}</b> - ${d.nama_aset_manual || ''}` : "-"
            },
            { 
                "data": "luas_areal", 
                "render": d => d ? parseFloat(d).toLocaleString('id-ID') + ' Ha' : '0 Ha',
                "className": "text-end"
            },
            { 
                "data": null,
                "render": function(d) {
                    let st = 'BAIK', cl = 'bg-success';
                    if (d.pintu_rusak_berat > 0) { st = 'RB'; cl = 'bg-danger'; }
                    else if (d.pintu_rusak_ringan > 0) { st = 'RR'; cl = 'bg-warning text-dark'; }
                    return d.pintu_total_unit > 0 ? `<div class="text-center"><span class="badge ${cl}">${st}</span><br><small>${d.nama_jenis_pintu || '-'}</small></div>` : '-';
                }
            },
            { 
                data: null,
                className: 'small',
                render: function(data, type, row) {
                    // Gabungkan semua status
                    let res = '';
                    if (row.sal_induk_baik > 0) res += `<span class="text-success">B: ${row.sal_induk_baik}m</span><br>`;
                    if (row.sal_induk_rusak_ringan > 0) res += `<span class="text-warning">RR: ${row.sal_induk_rusak_ringan}m</span><br>`;
                    if (row.sal_induk_rusak_berat > 0) res += `<span class="text-danger">RB: ${row.sal_induk_rusak_berat}m</span><br>`;
                    if (row.sal_induk_bap > 0) res += `<span class="text-muted">BAP: ${row.sal_induk_bap}m</span>`;
                    
                    return res || '-';
                }
            },
            { 
                data: null,
                className: 'small',
                render: function(data, type, row) {
                    // Gabungkan semua status
                    let res = '';
                    if (row.sal_sekunder_baik > 0) res += `<span class="text-success">B: ${row.sal_sekunder_baik}m</span><br>`;
                    if (row.sal_sekunder_rusak_ringan > 0) res += `<span class="text-warning">RR: ${row.sal_sekunder_rusak_ringan}m</span><br>`;
                    if (row.sal_sekunder_rusak_berat > 0) res += `<span class="text-danger">RB: ${row.sal_sekunder_rusak_berat}m</span><br>`;
                    if (row.sal_sekunder_bap > 0) res += `<span class="text-muted">BAP: ${row.sal_sekunder_bap}m</span>`;
                    
                    return res || '-';
                }
            },
            { 
                "data": null, 
                "render": function(data, type, row) {

                    return `<button class="btn btn-sm btn-info text-white" 
                            onclick="showDetailPaiIksi(${row.id}, '${row.nomenklatur_ruas}')">
                            <i class="fa-solid fa-eye"></i></button>`;
                }
            }
        ]
    });


    $('#tabelBangunan tbody').off('click', 'button.btn-toggle-map').on('click', 'button.btn-toggle-map', function () {
        var tr = $(this).closest('tr');
        var row = tableBangunanInstance.row(tr);
        var rowData = row.data();

        if (row.child.isShown()) {
            $('div.slider', row.child()).slideUp(function () { row.child.hide(); tr.removeClass('shown'); });
        } else {
            tableBangunanInstance.rows().every(function () {
                if (this.child.isShown()) { this.child.hide(); $(this.node()).removeClass('shown'); }
            });

            var diIdAktif = $('#id_di_aktif').val();
            var urlGeojsonDariModal = $(`.view-detail[data-id="${diIdAktif}"]`).attr('data-geojson');
            

            rowData.geojson = urlGeojsonDariModal; 

            console.log("DEBUG: Menitipkan URL GeoJSON ke baris:", rowData.geojson);


            var mapId = 'map-' + rowData.id;
            row.child(formatChildRow(mapId, rowData)).show();
            tr.addClass('shown');
            $('div.slider', row.child()).slideDown();

            initChildMap(mapId, rowData);
        }
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

        // 3. Update Summary Inventory (Sesuaikan dengan Key API Bapak)
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
