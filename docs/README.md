# Tài liệu — Sổ Thu Chi

Mục lục tài liệu của dự án. Tài liệu kỹ thuật (kiến trúc, API, cách chạy)
đã có sẵn và đầy đủ ở hai README riêng — không lặp lại ở đây:

- **Kỹ thuật backend** (NestJS/TypeORM/PostgreSQL, danh sách endpoint đầy
  đủ, cách deploy lên Render+Neon): [`backend/README.md`](../backend/README.md)
- **Kỹ thuật mobile** (Flutter, tính năng đã implement, các đơn giản hóa
  so với spec gốc, hướng dẫn build iOS): [`mobile/README.md`](../mobile/README.md)
- **Đặc tả sản phẩm đầy đủ** (thiết kế ban đầu, một phần chưa/không còn
  khớp 100% với implementation — 2 README trên là nguồn chính xác nhất về
  hiện trạng): [`../readme.md`](../readme.md)

Tài liệu phục vụ việc nộp app lên store:

- [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) — chính sách quyền riêng tư.
  **Đã public tại https://sothuchi-d055a.web.app** (Firebase Hosting, dự
  án `sothuchi-d055a`) — dùng thẳng link này khi nộp, source ở
  `hosting/public/index.html`, deploy lại bằng
  `firebase deploy --only hosting --project sothuchi-d055a` (chạy trong
  thư mục `hosting/`) sau khi sửa nội dung.
- [`STORE_LISTING.md`](STORE_LISTING.md) — nội dung mô tả, từ khóa, ảnh
  chụp màn hình cần chuẩn bị cho Play Console / App Store Connect.
- [`SUBMISSION_CHECKLIST.md`](SUBMISSION_CHECKLIST.md) — checklist từng
  bước để nộp lên Google Play và App Store; mục 0 liệt kê những gì **đã
  xong** (keystore, ký release, xoá tài khoản, Excel export).
