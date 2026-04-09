// Variabel global khusus untuk peta detail di modal
let detailMap = null;
let detailGrupKategori = {};
let detailLayerBangunanGroup = null;

let modalPanelDataOriginal = { primer: [], sekunder: [], tersier: [], bangunan: [] };
let modalPanelDataFiltered = { primer: [], sekunder: [], tersier: [], bangunan: [] };
let modalPanelPage = { primer: 1, sekunder: 1, tersier: 1, bangunan: 1 };
let modalDictLayerSaluran = {}; 
let modalCurrentActiveSegments = null;
let modalCurrentActiveSaluranId = null;

window.activeBlinkPolygon = null;
window.activeBlinkMarker = null;

function matikanSemuaKedipan() {
    if (window.activeBlinkPolygon) {
        const domPath = window.activeBlinkPolygon.getElement();
        if (domPath) domPath.classList.remove('polygon-blink');
        window.activeBlinkPolygon = null;
    }
    if (window.activeBlinkMarker) {
        if (window.activeBlinkMarker._icon) window.activeBlinkMarker._icon.classList.remove('marker-blink');
        window.activeBlinkMarker = null;
    }
}

// Fungsi membersihkan string untuk pencocokan yang lebih "kebal"
function cleanString(str) {
    if (!str) return "";
    return String(str).replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
}

window.renderModalPanelList = function(kategori) {
    const items = modalPanelDataFiltered[kategori] || [];
    const page = modalPanelPage[kategori] || 1;
    const perPage = 5; 
    const totalPages = Math.ceil(items.length / perPage) || 1;

    if (items.length === 0) {
        $(`#modal-list-map-${kategori}`).html(`<div class="p-3 text-center text-muted small" style="margin-top: 2rem;"><i>Data tidak ditemukan</i></div>`);
        $(`#modal-pag-${kategori}`).html(''); 
        return;
    }

    const start = (page - 1) * perPage;
    const end = start + perPage;
    const sliced = items.slice(start, end);

    let htmlList = sliced.map(item => item.html).join('');
    $(`#modal-list-map-${kategori}`).html(htmlList);

    let pagHtml = `
        <div style="font-size:9px;">Total: <b>${items.length}</b></div>
        <div>
            <button class="pagination-btn" onclick="window.gantiPageModalPanel('${kategori}', -1)" ${page <= 1 ? 'disabled' : ''}><i class="fa-solid fa-chevron-left"></i></button>
            <span class="mx-1 fw-bold">Hal ${page}/${totalPages}</span>
            <button class="pagination-btn" onclick="window.gantiPageModalPanel('${kategori}', 1)" ${page >= totalPages ? 'disabled' : ''}><i class="fa-solid fa-chevron-right"></i></button>
        </div>
    `;
    $(`#modal-pag-${kategori}`).html(pagHtml);
};

window.gantiPageModalPanel = function(kategori, arah) {
    modalPanelPage[kategori] += arah;
    window.renderModalPanelList(kategori);
};


function initDetailMap(inputData) {
    if (detailMap !== null) { 
        detailMap.remove(); 
        detailMap = null; 
    }
    
    matikanSemuaKedipan();
    
    detailLayerBangunanGroup = L.featureGroup();
    modalPanelDataOriginal = { primer: [], sekunder: [], tersier: [], bangunan: [] };
    modalPanelDataFiltered = { primer: [], sekunder: [], tersier: [], bangunan: [] };
    modalPanelPage = { primer: 1, sekunder: 1, tersier: 1, bangunan: 1 };
    modalDictLayerSaluran = {};
    modalCurrentActiveSegments = null;
    modalCurrentActiveSaluranId = null;

    const mapContainer = document.getElementById('mapDetail');
    if (!mapContainer) return;

    detailMap = L.map('mapDetail', { zoomControl: false, preferCanvas: true }).setView([-6.826, 108.604], 14); 
    
    detailMap.createPane('paneWilayahDetail'); detailMap.getPane('paneWilayahDetail').style.zIndex = 330;
    detailMap.createPane('paneLahanDetail'); detailMap.getPane('paneLahanDetail').style.zIndex = 340;
    detailMap.createPane('panePendukungDetail'); detailMap.getPane('panePendukungDetail').style.zIndex = 350;
    detailMap.createPane('paneSaluranDetail'); detailMap.getPane('paneSaluranDetail').style.zIndex = 600;
    detailMap.createPane('paneBangunanDetail'); detailMap.getPane('paneBangunanDetail').style.zIndex = 650;

    const baseMaps = {
        "Peta Dasar (Terang)": L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
        "Peta Satelit": L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
    };
    baseMaps["Peta Dasar (Terang)"].addTo(detailMap);

    detailGrupKategori = {
        'wilayah': L.featureGroup(),
        'jalan': L.featureGroup(),
        'irigasi': L.featureGroup(),
        'lahan': L.featureGroup(),
        'air': L.featureGroup()
    };

    const overlayMaps = {
        "<i class='fa-solid fa-location-dot text-danger'></i> Aset Bangunan": detailLayerBangunanGroup,
        "<i class='fa-solid fa-draw-polygon text-success'></i> Luas Fungsional": detailGrupKategori['lahan'],
        "<i class='fa-solid fa-road text-dark'></i> Jaringan Jalan": detailGrupKategori['jalan'],
        "<i class='fa-solid fa-map text-secondary'></i> Batas Wilayah": detailGrupKategori['wilayah'],
        "<i class='fa-solid fa-water text-info'></i> Sumber Air/Waduk": detailGrupKategori['air']
    };

    L.control.layers(baseMaps, overlayMaps, { collapsed: false }).addTo(detailMap);
    if (L.control.browserPrint) {
        L.control.browserPrint({
            title: 'Cetak Laporan Peta',
            printModesNames: { 
                Portrait: 'Potrait', 
                Landscape: 'Lanskap', 
                Auto: 'Otomatis', 
                Custom: 'Pilih Area' 
            }
        }).addTo(mapKeseluruhan);
    } else {
        console.error("Library Leaflet Browser Print belum terload sempurna!");
    }
    L.control.zoom({ position: 'bottomright' }).addTo(detailMap);

    Object.values(detailGrupKategori).forEach(group => group.addTo(detailMap));
    detailLayerBangunanGroup.addTo(detailMap);

    detailMap.on('popupclose', function() { matikanSemuaKedipan(); });
    detailMap.on('click', function() { matikanSemuaKedipan(); });

    const fsControl = L.Control.extend({
        options: { position: 'topright' },
        onAdd: function() {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control leaflet-control-custom');
            container.innerHTML = '<i class="fa-solid fa-expand"></i>';
            container.style.backgroundColor = 'white';
            container.style.width = '30px';
            container.style.height = '30px';
            container.style.display = 'flex';
            container.style.alignItems = 'center';
            container.style.justifyContent = 'center';
            container.style.cursor = 'pointer';
            
            container.onclick = function() {
                if (!document.fullscreenElement) {
                    if (mapContainer.requestFullscreen) mapContainer.requestFullscreen();
                    container.innerHTML = '<i class="fa-solid fa-compress"></i>';
                } else {
                    if (document.exitFullscreen) document.exitFullscreen();
                    container.innerHTML = '<i class="fa-solid fa-expand"></i>';
                }
            };
            return container;
        }
    });
    detailMap.addControl(new fsControl());
    document.addEventListener('fullscreenchange', () => { setTimeout(() => { if(detailMap) detailMap.invalidateSize(); }, 300); });

    const ModalListAsetControl = L.Control.extend({
        options: { position: 'topleft' }, 
        onAdd: function() {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control custom-map-panel');
            L.DomEvent.disableClickPropagation(container);
            L.DomEvent.disableScrollPropagation(container);

            container.innerHTML = `
                <div class="d-flex justify-content-between align-items-center" id="modal-btn-toggle-panel" style="cursor: pointer; padding-bottom: 4px; border-bottom: 1px solid #eee;">
                    <h6 class="fw-bold mb-0 text-primary" style="font-size:0.85rem;"><i class="fa-solid fa-list me-1"></i> Data Aset Peta</h6>
                    <i class="fa-solid fa-chevron-up text-secondary" id="modal-icon-toggle-panel" style="transition: transform 0.3s ease;"></i>
                </div>
                <div id="modal-panel-aset-body" style="padding-top: 8px;">
                    <input type="text" id="modal-map-search-input" class="form-control form-control-sm mb-2" placeholder="Cari aset di sini...">
                    <ul class="nav nav-pills nav-justified mb-2" style="font-size: 0.65rem;">
                        <li class="nav-item"><a class="nav-link active py-1 px-0 modal-panel-tab-btn" href="#modal-tab-map-primer">Primer</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 modal-panel-tab-btn" href="#modal-tab-map-sekunder">Sekunder</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 modal-panel-tab-btn" href="#modal-tab-map-tersier">Tersier</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 modal-panel-tab-btn" href="#modal-tab-map-bangunan">Bangunan</a></li>
                    </ul>
                    <div class="tab-content" style="flex-grow: 1; overflow: hidden; display: flex; flex-direction: column;">
                        <div class="panel-tab-content modal-panel-content" id="modal-tab-map-primer" style="display:block; height:100%; overflow-y:auto;"><div class="list-group list-group-flush" id="modal-list-map-primer"></div><div class="pagination-container" id="modal-pag-primer"></div></div>
                        <div class="panel-tab-content modal-panel-content" id="modal-tab-map-sekunder" style="display:none; height:100%; overflow-y:auto;"><div class="list-group list-group-flush" id="modal-list-map-sekunder"></div><div class="pagination-container" id="modal-pag-sekunder"></div></div>
                        <div class="panel-tab-content modal-panel-content" id="modal-tab-map-tersier" style="display:none; height:100%; overflow-y:auto;"><div class="list-group list-group-flush" id="modal-list-map-tersier"></div><div class="pagination-container" id="modal-pag-tersier"></div></div>
                        <div class="panel-tab-content modal-panel-content" id="modal-tab-map-bangunan" style="display:none; height:100%; overflow-y:auto;"><div class="list-group list-group-flush" id="modal-list-map-bangunan"></div><div class="pagination-container" id="modal-pag-bangunan"></div></div>
                    </div>
                </div>
            `;
            return container;
        }
    });
    detailMap.addControl(new ModalListAsetControl());


    let diId = (typeof inputData === 'object' && inputData !== null) ? $('#id_di_aktif').val() : inputData;

    if (diId) {
        let activeDiBounds = L.latLngBounds();
        let validPolygons = new Set(); 
        let currentDiName = cleanString($('#modalNama').text());

        Promise.all([
            fetch(`/api/bangunan/${diId}/`).then(res => res.json()),
            fetch(`/api/saluran/${diId}/`).then(res => res.json()),
            fetch('/api/layer-pendukung/').then(res => res.json())
        ])
        .then(([resBangunan, resSaluran, layers]) => {

            // ==========================================
            // 5A. RENDER MARKER BANGUNAN (SOLUSI POPUP)
            // ==========================================
            const daftarBangunan = resBangunan.data || [];
            modalPanelDataOriginal.bangunan = [];

            daftarBangunan.forEach(b => {
                let rawLat = parseFloat(b.latitude);
                let rawLng = parseFloat(b.longitude);
                let fixLat = (Math.abs(rawLat) > 90) ? rawLng : rawLat;
                let fixLng = (Math.abs(rawLat) > 90) ? rawLat : rawLng;

                if (fixLat !== 0 && !isNaN(fixLat)) {
                    // Target Cari Lahan (nama ruas / nama D.I.)
                    const targetCariData = cleanString(b.nomenklatur_ruas || b.nama_di);
                    if (targetCariData) validPolygons.add(targetCariData);

                    const iconAset = L.icon({
                        iconUrl: `/static/icons/${b.kode_aset || 'default'}.png`,
                        iconSize: [28, 28], iconAnchor: [14, 14], popupAnchor: [0, -14]
                    });

                    const marker = L.marker([fixLat, fixLng], { 
                        icon: iconAset, pane: 'paneBangunanDetail', dataTargetCari: targetCariData
                    }).addTo(detailLayerBangunanGroup);
                    
                    activeDiBounds.extend(marker.getLatLng());

                    // --- SOLUSI JUDUL POPUP ("BChl. 4") ---
                    // Kita ambil dari nomenklatur_ruas, kalau kosong baru nama_aset_manual
                    let judulBangunan = b.nomenklatur_ruas || b.nama_aset_manual || b.nomenklatur || 'Aset Bangunan';
                    let warnaKondisi = '#0d3b66'; // Biru default
                    if (b.kondisi_bangunan === 'BAIK' || b.kondisi_aset === 'BAIK') warnaKondisi = '#28a745';
                    if (b.kondisi_bangunan === 'RR' || b.kondisi_aset === 'RR') warnaKondisi = '#ffc107';
                    if (b.kondisi_bangunan === 'RB' || b.kondisi_aset === 'RB') warnaKondisi = '#dc3545';

                    const popupContent = `
                        <div style="min-width:200px; font-family: sans-serif;">
                            <div style="background:${warnaKondisi}; color:white; padding:8px; border-radius:4px 4px 0 0; font-weight:bold; text-align:center;">
                                ${judulBangunan}
                            </div>
                            <div style="padding:10px; border:1px solid #ddd; border-top:none; background:white;">
                                <div class="alert alert-warning p-1 mb-2 mt-0" style="font-size: 0.75rem;">
                                    <i class="fas fa-info-circle"></i> <b>Catatan:</b><br>
                                    <span class="text-muted">${b.keterangan || 'Tidak ada catatan khusus.'}</span>
                                </div>
                                <table style="width:100%; font-size:12px; border-collapse:collapse; margin-bottom:10px;">
                                    <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>Kode</b></td><td class="text-end">${b.kode_aset_display || b.kode_aset || '-'}</td></tr>
                                    <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>Kondisi</b></td><td class="text-end"><b>${b.kondisi_bangunan || b.kondisi_aset || '-'}</b></td></tr>
                                    <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>D.I.</b></td><td class="text-end">${b.nama_di || b.di || '-'}</td></tr>
                                    
                                    <tr style="border-bottom:1px solid #eee;">
                                        <td style="padding:4px 0; color:#0d3b66;"><b>Luas Layanan</b></td>
                                        <td class="text-end"><b>${b.luas_areal || b.luas_layanan_ha || '0'} Ha</b></td>
                                    </tr>
                                    <tr style="border-bottom:1px solid #eee;">
                                        <td style="padding:4px 0;"><b>Area (Spasial)</b></td>
                                        <td class="text-end"><span id="modal-area-spasial-${b.id}">${b.nomenklatur_ruas || '-'}</span></td>
                                    </tr>

                                    <tr><td style="padding:4px 0;"><b>Surveyor</b></td><td class="text-end">${b.surveyor || '-'}</td></tr>
                                </table>
                                
                                ${b.foto_aset ? 
                                    `<img src="${b.foto_aset}" style="width:100%; height:120px; object-fit:cover; border-radius:4px;">` : 
                                    `<div style="text-align:center; color:#999; font-size:11px; padding:10px; border:1px dashed #ccc;">Foto belum tersedia</div>`
                                }

                                <div id="modal-info-area-${b.id}"></div>

                                <button onclick="showDetailPaiIksi(${b.id})" class="btn btn-sm w-100" 
                                        style="background:#0d3b66; color:white; margin-top:10px; border:none; padding:8px; cursor:pointer; font-weight:bold;">
                                    <i class="fa-solid fa-eye"></i> LIHAT DETAIL
                                </button>
                            </div>
                        </div>
                    `;
                    marker.bindPopup(popupContent);

                    // KLIK MARKER -> LAHAN BLINK
                    marker.on('click', function(e) {
                        if (targetCariData) {
                            matikanSemuaKedipan();
                            let found = false;
                            detailGrupKategori['lahan'].eachLayer(function(geoJsonLayer) {
                                geoJsonLayer.eachLayer(function(polygonLayer) {
                                    const namaAsli = cleanString(polygonLayer.options.kunciPencarian);
                                    if (namaAsli === targetCariData) {
                                        found = true;
                                        window.activeBlinkPolygon = polygonLayer;
                                        const domPath = polygonLayer.getElement();
                                        if (domPath) {
                                            polygonLayer.bringToFront();
                                            domPath.classList.add('polygon-blink');
                                        }

                                        const props = polygonLayer.feature.properties;
                                        const luasBaku = props.luas_fungsional || props.Luas_Fung || props.LUAS || "0";
                                        const namaPasti = polygonLayer.options.kunciPencarian || "Area Spasial";

                                        // Update area spasial label in popup
                                        const areaLabel = document.getElementById(`modal-area-spasial-${b.id}`);
                                        if (areaLabel) areaLabel.innerText = namaPasti;
                                    }
                                });
                            });
                            if (!found) console.warn("Pencarian: Lahan belum tersedia untuk bangunan ini.");
                        }
                    });

                    // Rakit List Panel
                    let labelKondisi = (b.kondisi_bangunan || b.kondisi_aset || 'BAIK').toUpperCase();
                    let badgeColorClass = 'bg-success'; // Default Hijau (Baik)

                    if (labelKondisi.includes('RR') || labelKondisi.includes('RINGAN') || labelKondisi.includes('SEDANG')) {
                        badgeColorClass = 'bg-warning text-dark'; // Kuning
                    } else if (labelKondisi.includes('RB') || labelKondisi.includes('BERAT')) {
                        badgeColorClass = 'bg-danger'; // Merah
                    } else if (labelKondisi.includes('BAP') || labelKondisi.includes('PASANGAN')) {
                        badgeColorClass = 'bg-secondary'; // Abu-abu
                    }

                    // Rakit List Panel yang sudah berwarna warni
                    let itemHtml = `
                        <div class="list-group-item modal-item-bangunan" data-lat="${fixLat}" data-lng="${fixLng}" style="cursor:pointer; border-left: 4px solid ${warnaKondisi}; margin-bottom: 2px; border-radius: 4px;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px;">
                                <b style="font-size: 11px; color: #333; max-width: 70%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                    ${judulBangunan}
                                </b>
                                <span class="badge ${badgeColorClass}" style="font-size: 8px; min-width: 45px;">${labelKondisi}</span>
                            </div>
                            <div style="font-size: 9px; color: #666;"><i class="fa-solid fa-map-pin" style="color: #dc3545;"></i> ${b.nama_di || b.di || '-'}</div>
                        </div>`;
                    
                    modalPanelDataOriginal.bangunan.push({ 
                        name: judulBangunan.toLowerCase(), 
                        html: itemHtml 
                    });
                }
            });

            modalPanelDataFiltered.bangunan = [...modalPanelDataOriginal.bangunan];
            window.renderModalPanelList('bangunan');


            // ------------------------------------------
            // 5B. RENDER LAYER PENDUKUNG (LAHAN)
            // ------------------------------------------
            layers.forEach(layer => {
                if (layer.file_geojson && layer.file_geojson.toLowerCase().endsWith('.json')) {
                    fetch(layer.file_geojson + "?v=" + new Date().getTime())
                        .then(r => r.json())
                        .then(geojsonData => {
                            let targetPane = 'panePendukungDetail';
                            if (layer.kategori === 'wilayah') targetPane = 'paneWilayahDetail';
                            if (layer.kategori === 'lahan') targetPane = 'paneLahanDetail';

                            const gLayer = L.geoJSON(geojsonData, {
                                pane: targetPane,
                                filter: function(f) {
                                    if (layer.kategori === 'lahan') {
                                        let featName = cleanString(f.properties.nama_di || f.properties.Nama_DI || f.properties.nama || f.properties.Name);
                                        // Filter lahan khusus DI ini / yang terhubung bangunan
                                        if (validPolygons.has(featName)) return true;
                                        if (currentDiName && featName.includes(currentDiName)) return true;
                                        return false; 
                                    }
                                    return true;
                                },
                                style: {
                                    color: layer.warna_garis || '#3388ff',
                                    weight: layer.kategori === 'jalan' ? 3 : 2,
                                    fillOpacity: (layer.kategori === 'wilayah' || layer.kategori === 'lahan') ? 0.3 : 0,
                                    dashArray: layer.kategori === 'wilayah' ? '5, 5' : '0'
                                },
                                onEachFeature: (f, l) => {
                                    let namaPasti = layer.nama;
                                    if (layer.kategori === "lahan") {
                                        namaPasti = f.properties.nama_di || f.properties.Nama_DI || f.properties.nama || f.properties.Name || "Area Spasial";
                                    }
                                    l.bindTooltip(namaPasti, { sticky: true });
                                    l.options.kunciPencarian = namaPasti;

                                    // KLIK LAHAN -> MARKER BLINK
                                    if (layer.kategori === 'lahan') {
                                        l.on('click', function(e) {
                                            const kunciPoligon = cleanString(namaPasti);
                                            L.DomEvent.stopPropagation(e);
                                            matikanSemuaKedipan();

                                            window.activeBlinkPolygon = e.target;
                                            const domPath = e.target.getElement(); 
                                            if (domPath) {
                                                domPath.classList.add('polygon-blink');
                                                e.target.bringToFront(); 
                                            }

                                            let markerKetemu = false;
                                            detailLayerBangunanGroup.eachLayer(function(marker) {
                                                if (marker.options.dataTargetCari === kunciPoligon) {
                                                    markerKetemu = true;
                                                    window.activeBlinkMarker = marker;
                                                    if (window.activeBlinkMarker._icon) {
                                                        window.activeBlinkMarker._icon.classList.add('marker-blink');
                                                    }
                                                    setTimeout(() => { marker.openPopup(); }, 200); 
                                                }
                                            });
                                            if (!markerKetemu) console.warn("Pencarian:", kunciPoligon, "- Belum ada bangunan.");
                                        });
                                    }
                                }
                            });

                            if (detailGrupKategori[layer.kategori]) {
                                gLayer.addTo(detailGrupKategori[layer.kategori]);
                                // Tambahkan bounds jika layer tidak kosong
                                if (layer.kategori === 'lahan' && gLayer.getLayers().length > 0) {
                                    activeDiBounds.extend(gLayer.getBounds());
                                }
                            }
                        });
                }
            });


            // ------------------------------------------
            // 5C. RENDER GARIS SALURAN
            // ------------------------------------------
            const daftarSaluran = resSaluran.data || [];
            modalPanelDataOriginal.primer = [];
            modalPanelDataOriginal.sekunder = [];
            modalPanelDataOriginal.tersier = [];

            daftarSaluran.forEach(saluran => {
                if (saluran.is_approved !== true) return;

                const geoData = saluran.geometry_data || saluran.geom;
                if (geoData && geoData.coordinates) {
                    const gLayer = L.geoJson(geoData, {
                        pane: 'paneSaluranDetail',
                        style: { color: "#2d93ad", weight: 5, opacity: 0.8 },
                        onEachFeature: function(feature, layer) {
                            layer.options.dataSaluran = saluran;
                            modalDictLayerSaluran[saluran.id] = layer;

                            const s_baik = parseFloat(saluran.panjang_baik) || 0;
                            const s_rr   = parseFloat(saluran.panjang_rr) || 0;
                            const s_rb   = parseFloat(saluran.panjang_rb) || 0;
                            const s_bap  = parseFloat(saluran.panjang_bap) || 0;
                            const totalP = parseFloat(saluran.panjang_saluran) || 0;
                            const totalK = s_baik + s_rr + s_rb + s_bap;
                            const pembagi = totalK > 0 ? totalK : (totalP > 0 ? totalP : 1);

                            const popupContent = `
                                <div style="min-width: 260px; font-family: sans-serif;">
                                    <div style="background: #0d3b66; color: white; padding: 8px; border-radius: 4px 4px 0 0; font-weight: bold; font-size: 13px; text-align: center;">DETAIL SALURAN</div>
                                    <div style="padding: 10px; border: 1px solid #ccc; border-top: none; background: #fff;">
                                        <table style="width: 100%; font-size: 11px; border-collapse: collapse; margin-bottom: 8px;">
                                            <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0; width: 35%;"><b>Nama</b></td><td>: <b>${saluran.nama_saluran}</b></td></tr>
                                            <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>Tingkat</b></td><td>: ${saluran.tingkat_jaringan || '-'}</td></tr>
                                            <tr><td style="padding: 4px 0;"><b>P. Total</b></td><td>: ${totalP.toLocaleString('id-ID')} m</td></tr>
                                        </table>
                                        
                                        <div style="background: #f8f9fc; border: 1px solid #e3e6f0; border-radius: 4px; padding: 8px; margin-top: 5px;">
                                            <div style="font-size: 10px; font-weight: bold; margin-bottom: 6px; color: #5a5c69;">KONDISI FISIK (Meter)</div>
                                            <div class="progress" style="height: 10px; border-radius: 5px; margin-bottom: 8px; background-color: #e9ecef; overflow: hidden; display: flex;">
                                                <div style="width: ${(s_baik/pembagi)*100}%; background-color: #1cc88a;" title="Baik"></div>
                                                <div style="width: ${(s_rr/pembagi)*100}%; background-color: #f6c23e;" title="RR"></div>
                                                <div style="width: ${(s_rb/pembagi)*100}%; background-color: #e74a3b;" title="RB"></div>
                                                <div style="width: ${(s_bap/pembagi)*100}%; background-color: #858796;" title="BAP"></div>
                                            </div>
                                            <table style="width: 100%; font-size: 9px; text-align: center;">
                                                <tr>
                                                    <td><span style="color:#1cc88a">B:</span>${s_baik}</td>
                                                    <td style="border-left:1px solid #ddd"><span style="color:#f6c23e">RR:</span>${s_rr}</td>
                                                    <td style="border-left:1px solid #ddd"><span style="color:#e74a3b">RB:</span>${s_rb}</td>
                                                    <td style="border-left:1px solid #ddd"><span style="color:#858796">BAP:</span>${s_bap}</td>
                                                </tr>
                                            </table>
                                        </div>
                                        <button onclick="ambilDataDanBukaModal(${saluran.id}, ${diId})" style="width: 100%; background: #007bff; color: white; border: none; padding: 6px; border-radius: 3px; cursor: pointer; font-size: 10px; font-weight: bold; margin-top:10px;">
                                            <i class="fa-solid fa-eye"></i> LIHAT DETAIL
                                        </button>
                                    </div>
                                </div>`;
                            layer.bindPopup(popupContent);
                            layer.bindTooltip(`<b>${saluran.nama_saluran}</b>`, { sticky: true });

                            // KLIK SALURAN -> BELANG BELANG
                            layer.on('click', function(e) {
                                const targetLayer = e.target;
                                modalCurrentActiveSaluranId = saluran.id;
                                
                                Object.values(modalDictLayerSaluran).forEach(l => {
                                    if (l.setStyle) l.setStyle({ color: "#2d93ad", weight: 5 });
                                });

                                if (targetLayer.setStyle) targetLayer.setStyle({ color: "#1cc88a", weight: 6 });
                                
                                if (modalCurrentActiveSegments) {
                                    detailMap.removeLayer(modalCurrentActiveSegments);
                                }
                                modalCurrentActiveSegments = L.featureGroup().addTo(detailMap);

                                if (saluran.segmen_list && saluran.segmen_list.length > 0) {
                                    saluran.segmen_list.forEach(segmen => {
                                        if (segmen.geometry_data && segmen.kondisi !== 'BAIK') {
                                            let warnaSegmen = "#2d93ad";
                                            if (segmen.kondisi === 'RR') warnaSegmen = "#f6c23e"; 
                                            if (segmen.kondisi === 'RB') warnaSegmen = "#e74a3b"; 
                                            if (segmen.kondisi === 'BAP') warnaSegmen = "#858796"; 

                                            L.geoJSON(segmen.geometry_data, {
                                                pane: 'paneSaluranDetail',
                                                style: { color: warnaSegmen, weight: 8, opacity: 1 },
                                                onEachFeature: function(f, l) { l.bindPopup(popupContent); }
                                            }).addTo(modalCurrentActiveSegments);
                                        }
                                    });
                                }
                                targetLayer.openPopup();
                            });
                        }
                    }).addTo(detailMap);

                    let itemHtml = `
                        <div class="list-group-item modal-item-saluran" data-sal-id="${saluran.id}" style="cursor:pointer;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px;">
                                <b style="font-size: 11px; color: #333; max-width: 75%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                    ${saluran.nama_saluran || '-'}
                                </b>
                                <span class="badge bg-info text-dark" style="font-size: 10px;">${parseFloat(saluran.panjang_saluran||0).toFixed(0)}m</span>
                            </div>
                            <div style="font-size: 9px; color: #666;"><i class="fa-solid fa-water" style="color: #0d3b66;"></i> ${saluran.tingkat_jaringan}</div>
                        </div>`;

                    let tingkat = (saluran.tingkat_jaringan || "").toLowerCase().trim();
                    let kodeSal = (saluran.kode_aset_saluran || "").toUpperCase().trim();
                    let namaSal = (saluran.nama_saluran || "").toLowerCase().trim();

                    let itemObj = { name: namaSal, html: itemHtml };

                    if (tingkat.includes('primer') || kodeSal === 'S01' || namaSal.includes('induk')) {
                        modalPanelDataOriginal.primer.push(itemObj);
                    } else if (tingkat.includes('sekunder') || kodeSal === 'S02') {
                        modalPanelDataOriginal.sekunder.push(itemObj);
                    } else {
                        modalPanelDataOriginal.tersier.push(itemObj);
                    }
                }
            });

            modalPanelDataFiltered.primer = [...modalPanelDataOriginal.primer];
            modalPanelDataFiltered.sekunder = [...modalPanelDataOriginal.sekunder];
            modalPanelDataFiltered.tersier = [...modalPanelDataOriginal.tersier];
            
            window.renderModalPanelList('primer');
            window.renderModalPanelList('sekunder');
            window.renderModalPanelList('tersier');

            // Set Peta menyesuaikan dengan bounds Lahan/Bangunan
            setTimeout(() => {
                if (activeDiBounds.isValid() && Object.keys(activeDiBounds).length > 0) {
                    if (isFinite(activeDiBounds.getNorthEast().lat)) {
                        detailMap.flyToBounds(activeDiBounds, { padding: [30, 30], duration: 1.5 });
                    }
                }
            }, 500);

        }).catch(err => console.error("❌ Error Fetching Map Data:", err));
    }
}

// --- EVENT LISTENER PANEL KIRI MODAL ---

$(document).on('click', '#modal-btn-toggle-panel', function() {
    const icon = $('#modal-icon-toggle-panel');
    $('#modal-panel-aset-body').slideToggle(300);
    if (icon.hasClass('fa-chevron-up')) {
        icon.removeClass('fa-chevron-up').addClass('fa-chevron-down');
    } else {
        icon.removeClass('fa-chevron-down').addClass('fa-chevron-up');
    }
});

$(document).on('click', '.modal-panel-tab-btn', function(e) {
    e.preventDefault();
    $('.modal-panel-tab-btn').removeClass('active');
    $(this).addClass('active');
    
    $('.modal-panel-content').hide();
    const targetId = $(this).attr('href');
    $(targetId).show();

    const targetKategori = targetId.replace('#modal-tab-map-', '');
    $('#modal-map-search-input').val('');
    modalPanelDataFiltered[targetKategori] = [...modalPanelDataOriginal[targetKategori]];
    modalPanelPage[targetKategori] = 1;
    window.renderModalPanelList(targetKategori);
});

$(document).on('keyup', '#modal-map-search-input', function() {
    let keyword = $(this).val().toLowerCase();
    let activeTabHref = $('.modal-panel-tab-btn.active').attr('href');
    let activeTabId = activeTabHref.replace('#modal-tab-map-', ''); 

    modalPanelDataFiltered[activeTabId] = modalPanelDataOriginal[activeTabId].filter(item => item.name.includes(keyword));
    modalPanelPage[activeTabId] = 1;
    window.renderModalPanelList(activeTabId);
});

$(document).on('click', '.modal-item-saluran', function() {
    const salId = $(this).data('sal-id');
    const layerObj = modalDictLayerSaluran[salId];

    Object.values(modalDictLayerSaluran).forEach(layer => {
        if (layer.setStyle) layer.setStyle({ color: "#2d93ad", weight: 4 });
    });

    if (layerObj) {
        if (layerObj.setStyle) layerObj.setStyle({ color: "#ffc107", weight: 8 });
        if (layerObj.getBounds && detailMap) {
            detailMap.flyToBounds(layerObj.getBounds(), { padding: [50, 50], maxZoom: 17, duration: 1.5 });
        }
        layerObj.openPopup();
    }
});

$(document).on('click', '.modal-item-bangunan', function() {
    const lat = parseFloat($(this).data('lat'));
    const lng = parseFloat($(this).data('lng'));
    if (detailMap) detailMap.flyTo([lat, lng], 18, { animate: true, duration: 1.5 });
});

function renderModalCharts(d) {
    const labels = ['Baik', 'Rusak Ringan', 'Rusak Berat', 'BAP'];
    const colors = ['#198754', '#ffc107', '#dc3545', '#6c757d'];

    const configs = [
        { id: 'chartPrimer', data: [d.primer_baik || 0, d.primer_rr || 0, d.primer_rb || 0, d.primer_bap || 0] },
        { id: 'chartSekunder', data: [d.sekunder_baik || 0, d.sekunder_rr || 0, d.sekunder_rb || 0, d.sekunder_bap || 0] },
        { id: 'chartTersier', data: [d.tersier_baik || 0, d.tersier_rr || 0, d.tersier_rb || 0, d.tersier_bap || 0] }
    ];

    configs.forEach(config => {
        const canvas = document.getElementById(config.id);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        if (window[config.id] instanceof Chart) {
            window[config.id].destroy();
        }

        const totalValue = config.data.reduce((a, b) => a + b, 0);

        window[config.id] = new Chart(ctx, {
            type: 'doughnut',
            plugins: [ChartDataLabels], 
            data: {
                labels: labels,
                datasets: [{
                    data: totalValue === 0 ? [1] : config.data,
                    backgroundColor: totalValue === 0 ? ['#e9ecef'] : colors,
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    datalabels: {
                        display: totalValue > 0,
                        color: '#fff',
                        font: { weight: 'bold', size: 10 },
                        formatter: (val) => ((val * 100) / totalValue).toFixed(1) + "%"
                    },
                    legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 9 } } }
                },
                cutout: '65%'
            }
        });
    });
}