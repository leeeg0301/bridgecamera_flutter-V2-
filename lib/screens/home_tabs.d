import 'package:flutter/material.dart';
import 'tab_rename_one.dart';
import 'tab_zip_multi.dart';

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('점검도우미'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '1페이지: 저장'),
              Tab(text: '2페이지: ZIP'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TabRenameOne(),
            TabZipMulti(),
          ],
        ),
      ),
    );
  }
}
