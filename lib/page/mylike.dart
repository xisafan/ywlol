import 'package:flutter/material.dart';
import 'package:ovofun/services/api/ssl_Management.dart';

class MyLikePage extends StatefulWidget {
  const MyLikePage({Key? key}) : super(key: key);

  @override
  State<MyLikePage> createState() => _MyLikePageState();
}

class _MyLikePageState extends State<MyLikePage> {
  List<dynamic> _favorites = [];
  bool _loading = true;
  bool _editing = false;
  Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() => _loading = true);
    try {
      final res = await OvoApiManager.getFavorites();
      setState(() {
        _favorites = res['list'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败')));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    bool ok = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除选中的收藏吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _selected) {
      await OvoApiManager.deleteFavorite(id);
    }
    setState(() {
      _favorites.removeWhere((item) => _selected.contains(int.tryParse(item['vod_id'].toString()) ?? 0));
      _selected.clear();
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除成功')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('我的收藏'),
        actions: [
          if (_editing && _selected.isNotEmpty)
            TextButton(
              onPressed: _deleteSelected,
              child: Text('删除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  if (_editing && _selected.isEmpty) {
                    _editing = false;
                  } else {
                    _editing = !_editing;
                  }
                  _selected.clear();
                });
              },
              child: Text(_editing ? '取消' : '编辑', style: TextStyle(color: Colors.black)),
            ),
        ],
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(child: Text('暂无收藏'))
              : ListView.separated(
                  itemCount: _favorites.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey[300], height: 1),
                  itemBuilder: (context, i) {
                    final item = _favorites[i];
                    final vodId = int.tryParse(item['vod_id'].toString()) ?? 0;
                    final selected = _selected.contains(vodId);
                    return GestureDetector(
                      onTap: _editing
                          ? () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(vodId);
                                } else {
                                  _selected.add(vodId);
                                }
                              });
                            }
                          : null,
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['vod_pic'] ?? '',
                                width: 72,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 96,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['vod_name'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (_editing)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: _buildSelectCircle(selected),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    item['vod_remarks'] ?? '',
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildSelectCircle(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? Colors.blue : Colors.grey, width: 2),
        color: selected ? Colors.blue : Colors.white,
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
