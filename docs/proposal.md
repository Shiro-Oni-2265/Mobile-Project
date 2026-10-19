# Đề xuất NauGi — Sổ tay bếp cá nhân

> INT1449, PTIT. Đây là phạm vi đã chọn cho đồ án; không phải kết quả khảo sát người dùng. Nhóm tự điền thông tin thành viên và phân công trong README.

## Vấn đề và người dùng

Người tự nấu ăn thường lưu công thức, thực đơn và danh sách mua hàng thành nhiều ghi chú. Khi đi chợ, họ khó nhớ nguyên liệu đã có và món dự định nấu. Mạng yếu trong cửa hàng hoặc bếp làm việc tra cứu bất tiện.

NauGi hướng tới sinh viên ở trọ và người chuẩn bị bữa ăn cho gia đình nhỏ. Ứng dụng nối chuỗi công thức → thực đơn → nguyên liệu cần mua và lưu dữ liệu cá nhân trên điện thoại để tiếp tục dùng khi mất mạng. Đây là giả thuyết nhu cầu; nhóm cần bổ sung phản hồi thực tế nếu thực hiện khảo sát.

## Ý tưởng và lý do chọn di động

Người dùng xem công thức dùng chung từ REST API, lưu món yêu thích, xếp bữa theo ngày và nhập nguyên liệu trong tủ lạnh. Từ thực đơn, ứng dụng tính danh sách mua, có thể trừ lượng còn dùng được. Gợi ý dựa trên quy tắc về nguyên liệu, hạn dùng và tùy chọn ăn uống nên giải thích được lý do xuất hiện từng món.

Điện thoại phù hợp khi ở bếp và đi chợ; SQLite giữ thực đơn, tủ lạnh và danh sách mua trên thiết bị. Có thể chọn ảnh món từ thiết bị và bật nhắc hạn nguyên liệu. Nhắc hạn phụ thuộc quyền và cơ chế nền Android.

## Phạm vi đã chọn

| Trong phạm vi | Ngoài phạm vi |
|---|---|
| Flutter, ưu tiên Android, tiếng Việt | Cam kết iOS/web đã được kiểm thử đầy đủ |
| Công thức/nguyên liệu dùng chung qua json-server | Tài khoản, phân quyền và dữ liệu riêng trên máy chủ |
| Đọc/ghi danh mục qua REST khi online | Hàng đợi tự đồng bộ thao tác ghi offline |
| Cache đọc offline; thực đơn, tủ lạnh, mua sắm sửa offline | Đồng bộ dữ liệu cá nhân nhiều thiết bị |
| Yêu thích, tùy chọn và ảnh lưu cục bộ | Lưu ảnh trên đám mây |
| Sao chép mẫu rồi chỉnh sửa bản sao | Sửa/xóa công thức mẫu từ giao diện |
| Gợi ý quy tắc và ước tính dinh dưỡng | Gemini/LLM, tư vấn dinh dưỡng cá nhân hóa |

## Luồng chính

1. Công thức → tải REST/cache → tìm món → chi tiết → thêm vào thực đơn.
2. Nhập tủ lạnh/hạn dùng → xem gợi ý → chọn món → tạo danh sách mua từ thực đơn.
3. Tạo công thức online → POST API → cập nhật cache → mất mạng vẫn đọc được.
4. Offline → sửa thực đơn, tủ lạnh, mua sắm, tùy chọn → mở lại app để kiểm tra lưu bền.

## Lựa chọn và đánh đổi

| Lựa chọn | Quyết định |
|---|---|
| Flutter hoặc thay framework | Giữ Flutter từ nguồn NauGi, giảm viết lại UI; nhóm vẫn phải hiểu mã kế thừa. |
| Supabase có tài khoản hoặc REST mock | Chọn json-server 0.17.4 cổng 3000; dễ trình diễn HTTP/lỗi mạng, danh mục là dữ liệu dùng chung. |
| Ghi offline tự đồng bộ hoặc chỉ ghi online | Chọn ghi online để tránh xung đột và POST trùng khi timeout. |
| Tham chiếu món hoặc bản chụp thực đơn | Chọn bản chụp để sửa/xóa món gốc không làm mất bữa đã lên lịch. |
| LLM hoặc quy tắc | Chọn quy tắc để chạy offline và giải thích được điểm xếp hạng. |

## Dữ liệu và khó khăn chính

Recipe và Ingredient thuộc danh mục REST. MealEntry lưu bản chụp công thức; PantryLot, ShoppingList, Preferences, ID yêu thích và đường dẫn ảnh chỉ lưu SQLite. Luồng bắt buộc là View → AppController → KitchenRepository → RecipeApi/LocalStore.

Rủi ro chính là kết nối Android với máy chủ, cache bị hiểu nhầm là dữ liệu mới và mất dữ liệu cũ khi chuyển đổi. Cách xử lý nằm trong [kiến trúc](architecture.md), [REST](api-integration.md) và [kế hoạch chuyển đổi](migration-plan.md).

## Phân công và minh chứng

Nhóm tự thống nhất phạm vi sở hữu theo lát cắt từ màn hình đến dữ liệu, ghi vào bảng Contribution trong README. Tài liệu không gán công lao hoặc tỷ lệ cho thành viên.

Nhóm cần chạy các kịch bản online, airplane mode, timeout, dữ liệu rỗng, mở lại app và kích thước màn hình theo [testing-guide.md](testing-guide.md), rồi bổ sung bằng chứng thật. Danh sách kịch bản không phải kết quả đã chạy.
