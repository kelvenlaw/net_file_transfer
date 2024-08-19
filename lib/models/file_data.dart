class FileData {
  late String fileName;
  late int fileSize;
  late List<int> fileContent;
  String clientAddress;
  int status;           //状态：0=已连接；1=接收数据中；2=文件接收完成

  FileData({
    required this.fileName,
    required this.fileSize, 
    required this.clientAddress,
    required List<int> fileContent,
    required this.status,
  }) : fileContent = [];

  FileData.nameedConstructor({
    required this.clientAddress,
    required this.status,
  }) : fileContent = [];
  // FileData({
  //   required this.clientAddress
  // }) : fileContent = [];

  void addData(List<int> data) {
    fileContent.addAll(data);
  }

  bool isComplete() {
    return fileContent.length == fileSize;
  }
}
