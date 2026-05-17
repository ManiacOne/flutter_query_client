class Endpoints {
  // JSONPlaceholder — Posts CRUD
  static const String _jsonPlaceholder = 'https://jsonplaceholder.typicode.com';
  static String posts() => '$_jsonPlaceholder/posts';
  static String postById(int id) => '$_jsonPlaceholder/posts/$id';
  static String postComments(int postId) => '$_jsonPlaceholder/posts/$postId/comments';

  // DummyJSON — Products (paginated)
  static const String _dummyJson = 'https://dummyjson.com';
  static String products() => '$_dummyJson/products';
  static String productById(int id) => '$_dummyJson/products/$id';
  static String addProduct() => '$_dummyJson/products/add';
  static String updateProduct(int id) => '$_dummyJson/products/$id';
  static String deleteProduct(int id) => '$_dummyJson/products/$id';
  static String searchProducts() => '$_dummyJson/products/search';
}
