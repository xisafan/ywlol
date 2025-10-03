/// 套餐模型
class Package {
  final int id;
  final String name;
  final int groupId;
  final String groupName;
  final int credits;
  final int validityDays;
  final String description;
  final int sortOrder;
  final int status;
  final String createdAt;
  final String updatedAt;

  Package({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.credits,
    required this.validityDays,
    required this.description,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      groupId: json['group_id'] ?? 0,
      groupName: json['group_name'] ?? '',
      credits: json['credits'] ?? 0,
      validityDays: json['validity_days'] ?? 0,
      description: json['description'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      status: json['status'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group_id': groupId,
      'group_name': groupName,
      'credits': credits,
      'validity_days': validityDays,
      'description': description,
      'sort_order': sortOrder,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 根据天数获取描述
  String get validityDescription {
    if (validityDays <= 0) return '永久有效';
    if (validityDays < 30) return '${validityDays}天';
    if (validityDays < 365) {
      final months = (validityDays / 30).round();
      return '${months}个月';
    } else {
      final years = (validityDays / 365).round();
      return '${years}年';
    }
  }

  /// 是否为推荐套餐（这里可以根据业务逻辑调整）
  bool get isRecommended {
    return name.contains('年度') || validityDays >= 365;
  }
}

/// 套餐列表响应模型
class PackageListResponse {
  final List<Package> packages;
  final Pagination pagination;

  PackageListResponse({
    required this.packages,
    required this.pagination,
  });

  factory PackageListResponse.fromJson(Map<String, dynamic> json) {
    final packagesList = (json['packages'] as List?)
        ?.map((item) => Package.fromJson(item))
        .toList() ?? [];
    
    final paginationData = json['pagination'] ?? {};
    
    return PackageListResponse(
      packages: packagesList,
      pagination: Pagination.fromJson(paginationData),
    );
  }
}

/// 分页信息模型
class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'total_pages': totalPages,
    };
  }
}
