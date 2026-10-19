# Thiết lập Supabase, Google và Gemini

## 1. Chuẩn bị Supabase

1. Tạo tài khoản và project tại https://supabase.com/dashboard. Chọn gói Free; lưu mật khẩu database riêng.
2. Trong SQL Editor, chạy toàn bộ `supabase/migrations/202610190001_naugi.sql` **một lần** trên project mới.
3. Chạy `supabase/seed.sql` để nạp 20 công thức cho hàm AI. Seed có thể chạy lại.
4. Kiểm tra có `notebooks`, `recipe_catalog`, `ai_daily_usage` và bucket private `recipe-images`.
5. Lấy Project URL và publishable/anon key từ phần API/Connect của dashboard.
6. Sao chép `config/dev.example.json` thành `config/dev.json`, điền hai giá trị trên. Không điền service-role key.

Có thể dùng CLI thay SQL Editor nếu đã quen:

```powershell
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase db push
# Sau đó chạy supabase/seed.sql trong SQL Editor.
```

Không chạy migration lặp bằng SQL Editor; CLI theo dõi lịch sử migration. Nếu thay đổi schema, tạo migration mới.

## 2. Email và liên kết trở lại ứng dụng

1. Bật Email provider trong Authentication.
2. Đặt mật khẩu tối thiểu 8 ký tự để khớp kiểm tra trong ứng dụng.
3. Authentication → URL Configuration: thêm `vn.naugi.app://login-callback/` vào Redirect URLs.
4. Giữ email confirmation bật; đăng ký bằng địa chỉ bạn kiểm soát, mở email xác nhận trên thiết bị có cài app.
5. Thử cả xác nhận đăng ký và đặt lại mật khẩu trước ngày demo.
6. Nếu email mặc định bị giới hạn địa chỉ nhận hoặc hạn mức gửi, cấu hình SMTP của nhóm trong Auth.
   Dùng tài khoản SMTP và địa chỉ gửi đã xác minh; kiểm tra điều kiện miễn phí trực tiếp ở nhà cung cấp.
   Không tắt xác nhận email để che lỗi gửi thư.

Liên kết có thể mở trang lỗi nếu dùng trên máy chưa cài app hoặc chưa cho phép redirect.
Ứng dụng nhận deep link bằng `app_links` qua Supabase Flutter; không cần tự xử lý token trong mã giao diện.

## 3. Google OAuth

Theo tài liệu chính thức: https://supabase.com/docs/guides/auth/social-login/auth-google.

1. Tạo Google Cloud project và cấu hình OAuth consent screen. Ở chế độ Testing, thêm email của thành viên nhóm vào test users.
2. Tạo OAuth client **Web application** cho luồng browser của Supabase.
3. Thêm authorized redirect URI do Supabase hiển thị, thường là `https://<project-ref>.supabase.co/auth/v1/callback`.
4. Điền client ID và client secret vào Google provider trong Supabase; bật provider.
5. Giữ redirect trở lại app là `vn.naugi.app://login-callback/`.
6. Chạy app, bấm Google, chọn tài khoản thử nghiệm và kiểm tra quay về app.

Phiên bản này dùng OAuth qua trình duyệt, không dùng native Google Sign-In SDK;
không phải đưa Google client secret vào APK hay cấu hình Android client SHA để dùng luồng này.
Vẫn cần kiểm thử riêng APK release và email deep link.

## 4. Triển khai gợi ý AI

1. Tạo API key tại Google AI Studio: https://aistudio.google.com/.
2. Chọn model có hạn mức free tier trên tài khoản và khu vực của nhóm.
   Kiểm tra https://ai.google.dev/gemini-api/docs/pricing và trang hạn mức trong AI Studio.
   Không bật billing nếu nhóm chỉ dùng miễn phí. Không coi model/hạn mức là cố định mãi.
3. Tạo file tạm `.env` ở gốc dự án (đã được Git bỏ qua):

```dotenv
GEMINI_API_KEY=your-real-key
GEMINI_MODEL=your-available-free-model-id
```

4. Triển khai hàm bằng CLI:

```powershell
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase secrets set --env-file .env
npx supabase functions deploy suggest-recipes --no-verify-jwt
```

Hàm **tự xác thực bearer token bằng Auth.getUser** dù gateway JWT check được tắt.
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` do môi trường Supabase cung cấp;
không đưa chúng vào payload của người dùng. Service-role key chỉ được dùng ở hàm máy chủ để trừ hạn mức.

5. Đăng nhập app, bấm gợi ý AI. Kiểm tra kết quả chỉ chứa món trong thư viện.
6. Mỗi tài khoản được gọi tối đa 10 lần/ngày theo ngày Việt Nam, tính cả yêu cầu đã gửi nhưng nhà cung cấp thất bại.
   Hạn mức Gemini có thể thấp hơn. Hết hạn mức hiển thị không khả dụng; gợi ý theo nguyên liệu vẫn chạy.

Đọc log hàm trong dashboard để kiểm tra lỗi vận hành. Không log khóa, prompt hoặc nội dung sổ tay.

## 5. Chạy, đóng gói và kiểm tra

```powershell
flutter run --dart-define-from-file=config/dev.json
flutter build apk --release --dart-define-from-file=config/dev.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Chạy kịch bản trong `docs/TESTING.md` bằng hai tài khoản. Không nhập khóa vào chat hoặc commit file cấu hình thật.

Để dùng Supabase local cần Docker và Supabase CLI; không bắt buộc cho chế độ khách.
Sau `npx supabase start`, máy ảo Android dùng địa chỉ host `10.0.2.2` thay `127.0.0.1`.
APK mặc định không cho phép HTTP tùy ý: nên dùng HTTPS hoặc cấu hình network security riêng cho debug khi thử backend local.
