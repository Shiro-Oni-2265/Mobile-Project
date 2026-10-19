# Dữ liệu tham chiếu

20 công thức mẫu và danh mục nguyên liệu nằm trong `lib/data/catalog.dart`.
Giá trị dinh dưỡng là ước tính làm tròn theo nguyên liệu sống, phần ăn được,
tham khảo USDA SR Legacy: https://fdc.nal.usda.gov/download-datasets/.
Đây là danh mục tham chiếu nhỏ được nhập thủ công, không phải toàn bộ cơ sở dữ liệu USDA
và không có kết nối API USDA. Cần kiểm tra theo loại thực phẩm thực tế khi sử dụng.

Mặc định một quả trứng có phần ăn được 50 g, một quả cà chua 120 g.
Không quy đổi ml sang g. Nguyên liệu không có dữ liệu, lượng “vừa đủ” và
đơn vị không chuyển được sang g phải xuất hiện trong danh sách thiếu dữ liệu.
Tổng chưa đầy đủ là tổng phần đã biết, không phải tổng dinh dưỡng chính xác của món.
Người dùng có thể thêm/sửa giá trị trên 100 g và khối lượng mỗi quả/cái trong ứng dụng.
