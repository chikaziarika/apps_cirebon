document.addEventListener('DOMContentLoaded', function() {
    function initInlineMap(row) {
        const latInput = row.querySelector('[name$="-latitude"]');
        const lonInput = row.querySelector('[name$="-longitude"]');
        const diSelect = document.querySelector('#id_daerah_irigasi');
        const saluranSelect = document.querySelector('#id_saluran');

        // 1. Pindah Listener Dropdown ke tempat yang benar
        if (diSelect && !diSelect.dataset.listenerSet) {
            diSelect.dataset.listenerSet = "true";
            diSelect.addEventListener('change', () => location.reload());
        }

        if (!latInput || !lonInput || row.querySelector('.inline-map-container')) return;

        // 2. Buat Container Peta
        const mapDiv = document.createElement('div');
        mapDiv.className = 'inline-map-container';
        mapDiv.style.cssText = 'height:350px; margin:15px 0; border-radius:12px; border:2px solid #4e73df; z-index:1';
        row.querySelector('.module').appendChild(mapDiv);

        const map = L.map(mapDiv, { fullscreenControl: true }).setView([-6.826, 108.604], 16);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

        const savedLat = parseFloat(latInput.value);
        const savedLon = parseFloat(lonInput.value);

        // 3. Tentukan Kode Aset & Icon Awal
        const kodeSelect = row.querySelector('select[name$="-kode_aset"]');
        let kodeBersih = "default";
        if (kodeSelect && kodeSelect.value) {
            kodeBersih = kodeSelect.value.split('-')[0].trim().toLowerCase();
        }

        const iconUrl = `/static/icons/${kodeBersih}.png`;
        const kustomIcon = L.icon({
            iconUrl: iconUrl,
            iconSize: [32, 32],
            iconAnchor: [16, 32]
        });

        // 4. BUAT MARKER DULU (Kuncinya di sini Pak, harus dibuat sebelum fungsi update dipanggil)
        let initialPos = (savedLat && savedLon) ? [savedLat, savedLon] : [map.getCenter().lat, map.getCenter().lng];
        let marker = L.marker(initialPos, { draggable: true, icon: kustomIcon }).addTo(map);

        // 5. Fungsi Update Icon (Sekarang aman karena 'marker' sudah ada)
        const updateIcon = (val) => {
            if (!val) return;
            let currentKode = val.split('-')[0].trim().toLowerCase();
            let newIconUrl = `/static/icons/${currentKode}.png`;
            
            console.log(">>> Mengganti icon ke: " + newIconUrl);
            
            marker.setIcon(L.icon({
                iconUrl: newIconUrl,
                iconSize: [32, 32],
                iconAnchor: [16, 32]
            }));

            // Cek jika gambar error (Fallback)
            const tmpImg = new Image();
            tmpImg.src = newIconUrl;
            tmpImg.onerror = () => marker.setIcon(new L.Icon.Default());
        };

        // 6. Pasang Event Listener Dropdown
        if (kodeSelect) {
            kodeSelect.addEventListener('change', function() {
                updateIcon(this.value);
            });
        }

        // 7. Fitur Recenter & Drag
        if (savedLat && savedLon) {
            map.setView([savedLat, savedLon], 18);
        }

        marker.on('dragend', (e) => {
            const pos = e.target.getLatLng();
            latInput.value = pos.lat.toFixed(8);
            lonInput.value = pos.lng.toFixed(8);
            console.log(">>> Koordinat Disimpan:", latInput.value, lonInput.value);
        });

        // 8. Fungsi Gambar Garis & Load Referensi
        function renderGaris(geoData, label) {
            if (map.currentGeoLayer) map.removeLayer(map.currentGeoLayer);
            map.currentGeoLayer = L.geoJSON(geoData, {
                style: { color: '#ff4757', weight: 5, dashArray: '10, 10', opacity: 0.8 }
            }).addTo(map);
            
            if (!parseFloat(latInput.value)) {
                map.fitBounds(map.currentGeoLayer.getBounds(), { padding: [30, 30] });
            }
        }

        const loadReferenceLine = () => {
            let diId = diSelect ? diSelect.value : null;
            const targetSaluranId = saluranSelect ? saluranSelect.value : null;
            if (targetSaluranId) {
                fetch(`/api/saluran/${diId || "899"}/`)
                    .then(res => res.json())
                    .then(response => {
                        const match = response.data.find(s => String(s.id) === String(targetSaluranId));
                        if (match && match.geometry_data) renderGaris(match.geometry_data, match.nama_saluran);
                    });
            } else if (diId) {
                fetch(`/api/geojson/di/${diId}/`).then(res => res.json()).then(data => renderGaris(data, "D.I."));
            }
        };

        loadReferenceLine();
        console.log(">>> Peta Inline " + kodeBersih + " Dimuat");
    }

    document.querySelectorAll('.inline-related').forEach(initInlineMap);
});