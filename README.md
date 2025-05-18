# Air Quality Controll with Arduino Using AVR Assembly

Air Quality Controll adalah yang akan membantu masyarakat untuk memantau kualitas udara di lingkungan mereka dengan mudah dan akurat. Alat ini akan menggunakan Arduino
dan akan menggunakan bahasa pemrograman assembly.

## How the Project Works
Sistem ini menggunakan dua buah Arduino yang bekerja secara terpisah namun saling berkomunikasi. Arduino pertama bertugas untuk membaca data dari sensor DHT11 yang mengukur kelembapan dan suhu, serta sensor MQ-series yang mengukur kualitas udara berdasarkan kadar gas tertentu. Data hasil pembacaan sensor tersebut kemudian dikirim ke Arduino kedua melalui komunikasi serial. Arduino kedua berfungsi sebagai penerima data dan mengendalikan indikator output berupa tiga LED berwarna hijau, kuning, dan merah, serta sebuah buzzer sebagai alarm. LED hijau menyala ketika kualitas udara masih baik, LED kuning menyala saat kualitas udara mulai menurun, dan LED merah menyala jika kualitas udara buruk. Saat LED merah menyala, buzzer juga akan aktif sebagai tanda peringatan. Selain itu, Arduino kedua juga menampilkan data suhu, kelembapan, dan status kualitas udara melalui serial monitor untuk keperluan monitoring dan pencatatan. Dengan pengaturan ini, sistem mampu memberikan peringatan visual dan suara yang jelas mengenai kondisi kualitas udara secara real-time, sekaligus memberikan informasi lengkap melalui serial monitor.

## Authors ✍️

| Group 16  | Student Number |
| :----------------: | :------------: |
| [**Jonathan Frederick Kosasih**](https://github.com/JonathanKosasih18)| 2306225981 |
| [**Muhamad Rey Kafaka Fadlan**](https://github.com/MuhamadReyKF)| 2306250573 |
| [**Raddief Ezra Satrio Andaru**](https://github.com/Raddief)| 2306250693 |
| [**Muhammad Rafli**](https://github.com/MRafli127)| 2306250730 |
