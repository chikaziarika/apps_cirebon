import cv2
import numpy as np
import os

def start_surgical_clipping(image_input, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    img = cv2.imread(image_input)
    if img is None: return

    height, width, _ = img.shape
    
    # 1. PERLEBAR SEDIKIT: Dari 0.25 ke 0.30 
    # (Siapa tahu 2 icon itu posisinya agak mepet ke tengah)
    roi_width = int(width * 0.30) 
    img_left = img[:, 0:roi_width]

    gray = cv2.cvtColor(img_left, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # 2. TAMBAHKAN DILASI TIPIS: Agar garis icon yang putus tersambung
    kernel = np.ones((2,2), np.uint8)
    thresh = cv2.dilate(thresh, kernel, iterations=1)

    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    print(f"🧐 Memproses area kolom kiri...")

    count = 0
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        aspect_ratio = w / float(h)
        
        # 3. RASIO LEBIH TOLERAN: dari 0.5-2.0 ke 0.3-3.0
        if 0.3 < aspect_ratio < 3.0:
            if 10 < w < 200 and 10 < h < 200:
                icon_img = img_left[y:y+h, x:x+w]
                
                # 4. FILTER WARNA LEBIH SENSITIF:
                # Menurunkan batas saturasi agar icon pudar kena
                hsv = cv2.cvtColor(icon_img, cv2.COLOR_BGR2HSV)
                mask = cv2.inRange(hsv, np.array([0, 15, 15]), np.array([179, 255, 255]))
                
                # Cukup 2% pixel berwarna saja sudah dianggap icon
                if np.count_nonzero(mask) > (w * h * 0.02):
                    file_name = f"icon_{count}.png"
                    cv2.imwrite(os.path.join(output_dir, file_name), icon_img)
                    count += 1

    print(f"\n✨ GACOR! Dapat {count} icon. Cek folder sekarang!")

if __name__ == "__main__":
    gambar_sumber = 'katalog_epaksi3.png' 
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    folder_hasil = os.path.join(base_dir, 'static', 'icons')
    start_surgical_clipping(gambar_sumber, folder_hasil)