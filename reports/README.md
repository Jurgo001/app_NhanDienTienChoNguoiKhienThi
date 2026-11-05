# Báo cáo trước và sau tối ưu

- `TruocKhiToiUu/`: Word và JSON của mốc trước tối ưu.
- `SauKhiToiUu/`: Word đánh giá, Word thống kê so sánh, JSON số liệu và log kiểm chứng.
- Bản thống kê chi tiết: [ThongKe_SoSanh_Truoc_Sau_ToiUu_2026-11-04_135851.docx](SauKhiToiUu/ThongKe_SoSanh_Truoc_Sau_ToiUu_2026-11-04_135851.docx).

Các file Word/JSON đã chốt vẫn giữ ngày đo và đường dẫn ở thời điểm lập báo cáo. Đường dẫn lịch sử `reports/baseline/` tương ứng với `reports/TruocKhiToiUu/`; `reports/optimization/` tương ứng với `reports/SauKhiToiUu/`.

APK và `source-before.zip` là artifact cục bộ, được bỏ qua trong Git để tránh đưa bản build và bản sao source vào lịch sử repository. Thông số byte, SHA-256 và mẫu đo vẫn có trong JSON. Script `write_optimization_report.py` cần các APK cục bộ này nếu muốn tổng hợp lại toàn bộ phép đo.

Có thể tạo lại Word so sánh từ snapshot JSON đã đưa lên Git, không cần APK:

```powershell
python -X utf8 -B scripts/write_comparison_report.py
```

Mốc số liệu đã ghi nhận: APK release ARM64 giảm từ 40,34 xuống 32,70 MiB; trung vị detector debug trên ảnh tổng hợp giảm từ 120,06 xuống 98,38 ms; RSS trung bình các mốc cuối vòng tăng từ 386,47 lên 419,40 MiB. Pin và độ trễ TTS thực tế chưa đo. Xem Word để biết điều kiện và giới hạn so sánh.
