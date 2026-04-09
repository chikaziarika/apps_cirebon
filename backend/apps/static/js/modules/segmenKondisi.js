function gambarSegmenKondisi(coords, kondisi, total, map, parentLayer, type) {
    // Bersihkan segmen sebelumnya
    if (window.activeSegments) {
        window.activeSegments.forEach(s => map.removeLayer(s));
    }
    window.activeSegments = [];

    // Jika MultiLineString, ambil array koordinat pertama
    let flatCoords = (type === "MultiLineString") ? coords[0] : coords;

    if (!flatCoords || flatCoords.length < 2) return;

    const colors = [
        { key: 'baik', color: '#1cc88a' },
        { key: 'rr', color: '#f6c23e' },
        { key: 'rb', color: '#e74a3b' },
        { key: 'bap', color: '#858796' }
    ];

    let accumulatedRatio = 0;

    colors.forEach(item => {
        const panjangKondisi = kondisi[item.key];
        if (panjangKondisi <= 0) return;

        const ratioKondisi = panjangKondisi / total;
        const targetRatio = Math.min(accumulatedRatio + ratioKondisi, 1);
        
        let startIndex = Math.floor(accumulatedRatio * (flatCoords.length - 1));
        let endIndex = Math.ceil(targetRatio * (flatCoords.length - 1));
        
        let segmentCoords = flatCoords.slice(startIndex, endIndex + 1).map(c => [c[1], c[0]]);

        if (segmentCoords.length >= 2) {
            const poly = L.polyline(segmentCoords, {
                color: item.color,
                weight: 10, // Lebih tebal agar terlihat bedanya
                opacity: 1,
                lineCap: 'round',
                pane: map === detailMap ? 'paneSaluranDetail' : 'paneSaluran'
            }).addTo(map);
            
            window.activeSegments.push(poly);
        }
        accumulatedRatio = targetRatio;
    });

    // Reset saat popup ditutup
    parentLayer.on('popupclose', function() {
        parentLayer.setStyle({ opacity: 0.8, color: "#2d93ad", weight: 4 });
        if (window.activeSegments) {
            window.activeSegments.forEach(s => map.removeLayer(s));
            window.activeSegments = [];
        }
    });
}