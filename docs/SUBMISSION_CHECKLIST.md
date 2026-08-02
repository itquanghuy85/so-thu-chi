# Checklist nộp app — Sổ Thu Chi

Thứ tự thực hiện thực tế, kèm ghi chú những gì **đã sẵn sàng** trong repo và
những gì **còn thiếu** (đọc kỹ mục ⚠️ — có thể khiến app bị từ chối nếu bỏ
qua). Dùng cùng với `docs/STORE_LISTING.md` và `docs/PRIVACY_POLICY.md`.

## 0. ⚠️ Việc bắt buộc phải làm trước khi nộp (chưa có trong app)

- [ ] **Nút "Xóa tài khoản" trong app.** Cả Google Play (Data safety →
  yêu cầu có cách xóa dữ liệu nếu app cho tạo tài khoản) và Apple
  (Guideline 5.1.1(v)) đều bắt buộc nếu app cho đăng ký tài khoản — hiện
  Sổ Thu Chi có đăng ký/đăng nhập nhưng **chưa có màn hình xóa tài
  khoản**. Cách nhanh nhất: thêm nút trong Cài đặt → gọi một endpoint mới
  `DELETE /auth/account` xóa user + toàn bộ dữ liệu liên quan trong
  workspace mà họ là Owner duy nhất. Nếu chưa kịp code trước ngày nộp,
  Apple *có thể* tạm chấp nhận nếu bạn nêu rõ trong Review Notes rằng yêu
  cầu xóa xử lý qua email hỗ trợ — nhưng đây là rủi ro bị từ chối, không
  phải giải pháp lâu dài.
- [ ] **Deploy thay đổi backend mới nhất lên Render** — commit `fb7c3ec`
  thêm trường `created_by` vào API giao dịch chưa được deploy; không bắt
  buộc để nộp app nhưng nên làm trước để bản build nộp store có tính năng
  đầy đủ nhất.

## 1. Chuẩn bị chung (làm một lần)

- [ ] Đọc `docs/PRIVACY_POLICY.md`, đưa lên một URL công khai — 2 lựa chọn:
  - **Nhanh nhất:** publish file này thành một Claude Artifact rồi bấm
    **Share** để có link công khai (đã được tạo sẵn trong phiên làm việc
    này — xem link ở cuối tin nhắn).
  - **Bền vững hơn:** repo GitHub hiện đang **private**
    (`itquanghuy85/so-thu-chi`) nên link `github.com/.../blob/...` sẽ
    **không** công khai được. Nếu muốn dùng GitHub, cần bật GitHub Pages
    từ một repo public riêng chỉ chứa trang chính sách, hoặc chuyển repo
    này sang public (không khuyến nghị vì lộ mã nguồn/khóa cấu hình).
- [ ] Chuẩn bị 1 tài khoản demo (email/mật khẩu) đã có sẵn vài giao dịch
  mẫu — cả Google và Apple đều có thể yêu cầu tài khoản test để reviewer
  đăng nhập thử.
- [ ] Icon app 512×512 (Play) / 1024×1024 (App Store) — đã có sẵn tại
  `mobile/assets/icon/icon.png`, kiểm tra độ phân giải đủ trước khi dùng.

## 2. Android — Google Play

### 2.1. Ký release (chưa có trong repo)

```bash
cd mobile/android/app
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sothuchi
```
Trả lời các câu hỏi (tên, tổ chức...), đặt mật khẩu **mạnh và lưu lại an
toàn** — mất file này hoặc mật khẩu thì **không bao giờ** cập nhật được app
dưới cùng một listing trên Play Store nữa.

Tạo `mobile/android/key.properties` (đã có sẵn `.gitignore` chặn commit
file nhạy cảm — kiểm tra lại):
```properties
storePassword=<mật khẩu keystore>
keyPassword=<mật khẩu key>
keyAlias=sothuchi
storeFile=release.jks
```

Cập nhật `android/app/build.gradle.kts` để đọc `key.properties` và ký bản
`release` bằng keystore này thay vì debug key (hiện tại chưa cấu hình —
Claude có thể làm bước này khi bạn sẵn sàng, cần xác nhận trước vì đụng tới
file build gốc).

### 2.2. Đăng ký SHA-1/SHA-256 release vào Firebase

```bash
keytool -list -v -keystore release.jks -alias sothuchi
```
Copy SHA-1 và SHA-256 → Firebase Console → dự án `sothuchi-d055a` →
Project settings → app Android → Add fingerprint. **Bỏ qua bước này thì
Google Sign-In sẽ báo lỗi `DEVELOPER_ERROR` trên bản release** dù vẫn chạy
tốt ở bản debug.

### 2.3. Build

```bash
cd mobile
flutter build appbundle --release
```
File ra tại `build/app/outputs/bundle/release/app-release.aab`.

### 2.4. Google Play Console

- [ ] Tạo tài khoản Google Play Developer (phí một lần **25 USD**) tại
  play.google.com/console.
- [ ] Tạo app mới, package name `com.moneyflow.mobile`.
- [ ] **Store listing**: dán nội dung từ `docs/STORE_LISTING.md`, upload
  icon + ảnh chụp màn hình.
- [ ] **Content rating questionnaire**: trả lời theo mục "Phân loại nội
  dung" trong `docs/STORE_LISTING.md`.
- [ ] **Data safety form**: khai đúng theo `docs/PRIVACY_POLICY.md` — mục
  "Personal info" (email, tên, SĐT), "Financial info" (dữ liệu giao dịch),
  chọn "Data is encrypted in transit", và **chưa** tick "users can request
  data deletion" cho tới khi hoàn thành mục 0 ở trên.
- [ ] Dán **Privacy Policy URL** đã chuẩn bị ở bước 1.
- [ ] **App content** → Target audience: chọn nhóm tuổi phù hợp (không
  hướng đến trẻ em).
- [ ] Upload `.aab` vào kênh **Internal testing** trước, tự cài thử qua
  link nội bộ, xác nhận app mở được/đăng nhập được trước khi đẩy lên
  **Production**.
- [ ] Submit for review (thường 1-3 ngày với app mới).

## 3. iOS — App Store (cần máy Mac + Xcode)

Toàn bộ phần chuẩn bị không cần Mac đã xong (Firebase iOS app, Info.plist
usage strings — xem `mobile/README.md` mục "Building on macOS"). Các bước
còn lại **bắt buộc cần Mac**, không thể làm từ Windows hay từ một phiên
Claude chạy trên Chrome:

- [ ] Đăng ký **Apple Developer Program** (**99 USD/năm**) tại
  developer.apple.com.
- [ ] Trên Mac: cài Xcode, làm theo đúng 5 bước trong
  `mobile/README.md` § "Building on macOS" (mở `Runner.xcworkspace`, set
  Signing Team, thêm capability "Sign in with Apple" nếu muốn dùng, bật
  Apple provider trong Firebase Console).
- [ ] Tạo app record trong **App Store Connect**, Bundle ID
  `com.moneyflow.mobile` (phải khớp chính xác).
- [ ] Build & upload:
  ```bash
  flutter build ipa --release
  ```
  rồi mở Xcode Organizer (hoặc Apple Transporter) để upload lên App Store
  Connect.
- [ ] **App Privacy ("Nutrition label")**: khai từng mục dữ liệu dựa trên
  `docs/PRIVACY_POLICY.md` — quan trọng nhất: khai "Contact Info" (email,
  tên) và "Financial Info" (dữ liệu giao dịch) là **Linked to identity**
  nhưng **không dùng để tracking** (app không có SDK quảng cáo/analytics
  bên thứ ba nên trả lời "No" cho câu "Do you use data for tracking").
- [ ] Dán **Privacy Policy URL**.
- [ ] Upload ảnh chụp màn hình đúng size bắt buộc (iPhone 6.7" tối thiểu).
- [ ] Test qua **TestFlight** trước khi bấm submit — mời chính bạn làm
  tester nội bộ.
- [ ] ⚠️ Xác nhận đã xử lý mục 0 (xóa tài khoản) trước khi submit — đây là
  lý do bị từ chối phổ biến nhất cho app có đăng ký tài khoản.
- [ ] Submit for Review (thường 1-2 ngày, có thể lâu hơn ở lần nộp đầu).

## 4. Sau khi nộp

- [ ] Theo dõi trạng thái review hàng ngày (email + trong console).
- [ ] Nếu bị từ chối: đọc kỹ lý do (thường trích dẫn đúng guideline số),
  sửa, **reply trong Resolution Center** (App Store) hoặc nộp lại bản mới
  (Play) — không cần tạo listing từ đầu.
- [ ] Sau khi duyệt: giữ nguyên `release.jks`/Apple certificates cho các
  bản cập nhật sau — không tạo lại từ đầu.
