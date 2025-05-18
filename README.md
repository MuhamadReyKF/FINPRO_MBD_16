# Air Quality Controll with Arduino Using AVR Assembly

Air Quality Controll adalah yang akan membantu masyarakat untuk memantau kualitas udara di lingkungan mereka dengan mudah dan akurat. Alat ini akan menggunakan Arduino
dan akan menggunakan bahasa pemrograman assembly.

## How the Project Works
Sistem ini menggunakan dua buah Arduino yang bekerja secara terpisah namun saling berkomunikasi. Arduino pertama bertugas untuk membaca data dari sensor DHT11 yang mengukur kelembapan dan suhu, serta sensor MQ-series yang mengukur kualitas udara berdasarkan kadar gas tertentu. Data hasil pembacaan sensor tersebut kemudian dikirim ke Arduino kedua melalui komunikasi serial. Arduino kedua berfungsi sebagai penerima data dan mengendalikan indikator output berupa tiga LED berwarna hijau, kuning, dan merah, serta sebuah buzzer sebagai alarm. LED hijau menyala ketika kualitas udara masih baik, LED kuning menyala saat kualitas udara mulai menurun, dan LED merah menyala jika kualitas udara buruk. Saat LED merah menyala, buzzer juga akan aktif sebagai tanda peringatan. Selain itu, Arduino kedua juga menampilkan data suhu, kelembapan, dan status kualitas udara melalui serial monitor untuk keperluan monitoring dan pencatatan. Dengan pengaturan ini, sistem mampu memberikan peringatan visual dan suara yang jelas mengenai kondisi kualitas udara secara real-time, sekaligus memberikan informasi lengkap melalui serial monitor.

## 1. Introduction to the Problem and the Solution

### Problem Statement  
Di era modern ini, kualitas udara menjadi aspek penting yang mempengaruhi kesehatan dan kenyamanan manusia, terutama di lingkungan perkotaan dan area industri. Banyak lokasi masih mengalami pencemaran udara akibat partikel debu, gas berbahaya, dan bahan kimia yang berpotensi membahayakan kesehatan. Kurangnya sistem monitoring dan pengendalian kualitas udara secara real-time menyebabkan keterlambatan deteksi kondisi udara berbahaya, sehingga tindakan pencegahan menjadi kurang efektif.

### Proposed Solution  
Untuk mengatasi masalah tersebut, kami mengembangkan sistem Air Quality Control yang memantau kualitas udara secara kontinu menggunakan sensor DHT11 untuk suhu dan kelembapan, serta sensor gas MQ-2 untuk mendeteksi gas berbahaya. Sistem ini menggunakan Arduino sebagai pengendali utama dengan pemrograman assembly untuk efisiensi. Data hasil pengukuran ditampilkan secara real-time pada layar serial monitor, dan sistem memberikan peringatan melalui LED dan buzzer jika kualitas udara melewati ambang batas aman. Dengan alat ini, masyarakat dapat memantau dan mengambil langkah preventif untuk menjaga kualitas udara di lingkungan sekitar.

---

## 2. Hardware Design and Implementation Details

### Hardware Components  
- *Arduino Uno (2 buah):* Satu berperan sebagai master yang mengambil data dari sensor DHT11 dan MQ-2, satu lagi sebagai slave yang menerima data dan mengendalikan output LED serta buzzer.  
- *Sensor MQ-2:* Mendeteksi gas berbahaya seperti metana, karbon monoksida, dan gas mudah terbakar lainnya dengan output analog yang mewakili konsentrasi gas.  
- *Sensor DHT11:* Mengukur suhu dan kelembapan udara secara digital.  
- *LED (3 warna):* Menunjukkan status kualitas udara; hijau untuk baik, kuning untuk sedang, merah untuk buruk.  
- *Buzzer:* Memberikan peringatan suara saat kualitas udara buruk.  
- *Kabel jumper:* Menghubungkan komponen satu dengan yang lain di breadboard.

### Circuit and Connections  
Master Arduino terhubung ke sensor DHT11 di port digital 2 dan sensor MQ-2 di port analog A0. Komunikasi antar Arduino menggunakan protokol I2C melalui port PC4 (SDA) dan PC5 (SCL). Arduino slave mengendalikan LED pada port digital 2, 3, 4, dan buzzer di port 5. Komunikasi serial monitor terhubung ke port UART masing-masing Arduino untuk pemantauan data.

---

## 3. Software Implementation Details

### Master Arduino Program  
- Inisialisasi UART, I2C, dan sensor DHT11.  
- Membaca data suhu dan kelembapan dari DHT11 (disimulasikan untuk pengujian).  
- Membaca nilai analog dari MQ-2 sebagai indikator kualitas udara.  
- Menentukan status kualitas udara berdasarkan nilai ambang (baik, sedang, buruk).  
- Mengirim data suhu, kelembapan, nilai sensor gas, dan status kualitas udara ke Arduino slave melalui I2C.  
- Menampilkan data sensor secara real-time ke serial monitor.  
- Mengulangi proses pembacaan dan pengiriman data setiap 2 detik.

### Slave Arduino Program  
- Inisialisasi UART, I2C sebagai slave dengan alamat tertentu.  
- Menerima data dari master melalui interrupt I2C dan menyimpannya ke variabel.  
- Mengendalikan LED dan buzzer sesuai status kualitas udara yang diterima:  
  - LED hijau menyala jika udara baik  
  - LED kuning menyala jika udara sedang  
  - LED merah dan buzzer menyala jika udara buruk  
- Menampilkan data yang diterima ke serial monitor untuk monitoring.  
- Menyediakan fungsi uji coba LED dan buzzer secara bergantian untuk memastikan perangkat berfungsi.

### Programming Details  
Program dikembangkan menggunakan bahasa Assembly untuk mikrokontroler AVR (Arduino Uno). Fungsi-fungsi utama mencakup komunikasi serial UART, I2C, pembacaan sensor, pengolahan data, dan kontrol output. Program disusun modular dengan interrupt service routine pada I2C untuk efisiensi pengolahan data.

---

## 4. Test Results and Performance Evaluation

### Testing Procedure  
- Setelah perakitan dan pemrograman selesai, dilakukan pengujian sensor DHT11 dan MQ-2 pada Arduino master untuk memastikan data sensor terbaca dengan baik dan tampil pada serial monitor.  
- LED dan buzzer diuji pada Arduino slave dengan kode pengujian yang menyalakan tiap LED dan buzzer secara bergantian.  
- Ambang batas kualitas udara diuji dengan mengubah nilai sensor gas untuk memastikan buzzer menyala saat kondisi berbahaya.

### Results  
- Sensor suhu dan kelembapan berhasil mengukur dan menampilkan data sesuai ekspektasi.  
- Sensor MQ-2 mampu mendeteksi perubahan konsentrasi gas, dan data dapat dikirim ke Arduino slave dengan baik.  
- LED menunjukkan status kualitas udara dengan benar sesuai nilai yang diterima.  
- Buzzer menyala saat kualitas udara buruk, menandakan sistem alarm berfungsi sesuai harapan.

### Evaluation  
Sistem berhasil memenuhi kriteria fungsional, dengan komunikasi antar Arduino stabil dan data sensor dapat dipantau secara real-time. Alarm visual dan audio memberikan peringatan yang efektif. Pengujian menunjukkan alat cukup akurat untuk penggunaan dasar monitoring kualitas udara dalam lingkungan terbatas.

---

## 5. Conclusion and Future Work

### Conclusion  
Proyek Air Quality Control berhasil mengimplementasikan sistem monitoring suhu, kelembapan, dan kualitas udara menggunakan sensor DHT11 dan MQ-2 dengan mikrokontroler Arduino yang diprogram dalam Assembly. Sistem mampu memberikan peringatan melalui LED dan buzzer saat kondisi udara memburuk. Proyek ini menggabungkan modul komunikasi I2C antar Arduino master dan slave, serta menampilkan data sensor secara real-time untuk pemantauan.

### Future Work  
Pengembangan berikutnya dapat meliputi:  
- Integrasi dengan antarmuka pengguna berbasis layar LCD atau aplikasi mobile untuk monitoring lebih mudah.  
- Penambahan sensor gas lainnya untuk cakupan polutan yang lebih luas.  
- Optimalisasi algoritma pengolahan data untuk akurasi dan respon lebih cepat.  
- Implementasi komunikasi nirkabel untuk pengawasan jarak jauh.  
- Peningkatan desain perangkat keras agar lebih kompak dan tahan lama untuk penggunaan di lapangan.
## Authors ✍️

| Group 16  | Student Number |
| :----------------: | :------------: |
| [**Jonathan Frederick Kosasih**](https://github.com/JonathanKosasih18)| 2306225981 |
| [**Muhamad Rey Kafaka Fadlan**](https://github.com/MuhamadReyKF)| 2306250573 |
| [**Raddief Ezra Satrio Andaru**](https://github.com/Raddief)| 2306250693 |
| [**Muhammad Rafli**](https://github.com/MRafli127)| 2306250730 |
