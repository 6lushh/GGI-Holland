import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGI Holland - Stier Adviezen',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066CC),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, List<String>> excelData = {};
  bool filePicked = false;
  bool isLoading = false;
  String selectedFilePath = '';
  TextEditingController searchController = TextEditingController();
  List<String>? searchResults;

  @override
  void initState() {
    super.initState();
    _loadSavedFile();
  }

  Future<void> _loadSavedFile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('excel_file_path');
    
    if (savedPath != null && File(savedPath).existsSync()) {
      setState(() {
        selectedFilePath = savedPath;
      });
      await _loadExcelFile(savedPath);
    }
  }

  Future<void> _pickFile() async {
    try {
      final List<XTypeGroup> typeGroups = <XTypeGroup>[
        const XTypeGroup(
          label: 'Spreadsheets',
          extensions: <String>['xlsx', 'csv'],
        ),
        const XTypeGroup(
          label: 'Excel files',
          extensions: <String>['xlsx'],
        ),
        const XTypeGroup(
          label: 'CSV files',
          extensions: <String>['csv'],
        ),
      ];
      
      final XFile? file = await openFile(
        acceptedTypeGroups: typeGroups,
      );

      if (file == null) {
        return;
      }

      String filePath = file.path;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('excel_file_path', filePath);
      
      setState(() {
        selectedFilePath = filePath;
        searchResults = null;
      });
      
      await _loadExcelFile(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadExcelFile(String filePath) async {
    setState(() {
      isLoading = true;
    });

    try {
      Map<String, List<String>> tempData = {};

      if (filePath.endsWith('.csv')) {
        // Parse CSV file
        final file = File(filePath);
        final content = await file.readAsString();
        final List<List<dynamic>> rows = const CsvToListConverter().convert(content);

        if (rows.isEmpty) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bestand is leeg'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Parse headers (first row)
        List<String> headers = [];
        for (var cell in rows.first) {
          headers.add(cell?.toString().trim() ?? '');
        }

        // Find column indices (case-insensitive)
        int koeIndex = -1;
        int advies1Index = -1;
        int advies2Index = -1;
        int advies3Index = -1;

        for (int i = 0; i < headers.length; i++) {
          String header = headers[i].toLowerCase();
          if (header.contains('koe')) koeIndex = i;
          if (header.contains('advies') && header.contains('stier') && header.contains('1')) advies1Index = i;
          if (header.contains('advies') && header.contains('stier') && header.contains('2')) advies2Index = i;
          if (header.contains('advies') && header.contains('stier') && header.contains('3')) advies3Index = i;
        }

        // Check if required columns found
        if (koeIndex == -1) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kolom "Koe" niet gevonden.\nGevonden kolommen: ${headers.join(", ")}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Parse data rows
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.length > koeIndex && row[koeIndex] != null && row[koeIndex].toString().isNotEmpty) {
            String koeNummer = row[koeIndex].toString().trim();
            List<String> advies = [];
            
            if (advies1Index >= 0 && row.length > advies1Index && row[advies1Index] != null) {
              String val = row[advies1Index].toString().trim();
              if (val.isNotEmpty) advies.add(val);
            }
            if (advies2Index >= 0 && row.length > advies2Index && row[advies2Index] != null) {
              String val = row[advies2Index].toString().trim();
              if (val.isNotEmpty) advies.add(val);
            }
            if (advies3Index >= 0 && row.length > advies3Index && row[advies3Index] != null) {
              String val = row[advies3Index].toString().trim();
              if (val.isNotEmpty) advies.add(val);
            }
            
            if (advies.isNotEmpty) {
              tempData[koeNummer] = advies;
            }
          }
        }
      } else {
        // Parse Excel file
        final bytes = await File(filePath).readAsBytes();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet == null) continue;

          // Parse headers (first row)
          List<String> headers = [];
          if (sheet.rows.isNotEmpty) {
            for (var cell in sheet.rows.first) {
              headers.add(cell?.value?.toString() ?? '');
            }
          }

          // Find column indices (case-insensitive)
          int koeIndex = -1;
          int advies1Index = -1;
          int advies2Index = -1;
          int advies3Index = -1;

          for (int i = 0; i < headers.length; i++) {
            String header = headers[i].toLowerCase();
            if (header.contains('koe')) koeIndex = i;
            if (header.contains('advies') && header.contains('stier') && header.contains('1')) advies1Index = i;
            if (header.contains('advies') && header.contains('stier') && header.contains('2')) advies2Index = i;
            if (header.contains('advies') && header.contains('stier') && header.contains('3')) advies3Index = i;
          }

          // Check if required columns found
          if (koeIndex == -1) {
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kolom "Koe" niet gevonden.\nGevonden kolommen: ${headers.join(", ")}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Parse data rows
          for (int i = 1; i < sheet.rows.length; i++) {
            var row = sheet.rows[i];
            if (row.length > koeIndex && row[koeIndex] != null) {
              String koeNummer = row[koeIndex]!.value?.toString() ?? '';
              if (koeNummer.isNotEmpty) {
                List<String> advies = [];
                
                if (advies1Index >= 0 && row.length > advies1Index && row[advies1Index] != null) {
                  String val = row[advies1Index]!.value?.toString() ?? '';
                  if (val.isNotEmpty) advies.add(val);
                }
                if (advies2Index >= 0 && row.length > advies2Index && row[advies2Index] != null) {
                  String val = row[advies2Index]!.value?.toString() ?? '';
                  if (val.isNotEmpty) advies.add(val);
                }
                if (advies3Index >= 0 && row.length > advies3Index && row[advies3Index] != null) {
                  String val = row[advies3Index]!.value?.toString() ?? '';
                  if (val.isNotEmpty) advies.add(val);
                }
                
                if (advies.isNotEmpty) {
                  tempData[koeNummer] = advies;
                }
              }
            }
          }
        }
      }

      setState(() {
        excelData = tempData;
        filePicked = true;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${excelData.length} koeiën geladen!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij lezen bestand: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _searchKoe(String query) {
    query = query.trim();
    
    if (query.isEmpty) {
      setState(() {
        searchResults = null;
      });
      return;
    }

    // Try exact match first
    if (excelData.containsKey(query)) {
      setState(() {
        searchResults = excelData[query];
      });
    } else {
      // Try partial match if exact match fails
      List<String> matches = [];
      excelData.forEach((key, value) {
        if (key.toLowerCase().contains(query.toLowerCase())) {
          matches.add(key);
        }
      });
      
      if (matches.isNotEmpty) {
        setState(() {
          searchResults = excelData[matches.first];
        });
      } else {
        setState(() {
          searchResults = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GGI Holland - Stier Adviezen'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (filePicked)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _pickFile,
              tooltip: 'Ander bestand kiezen',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : !filePicked
              ? _buildFilePickerPage()
              : _buildSearchPage(),
    );
  }

  Widget _buildFilePickerPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_present,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'Excel-bestand nodig',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Kies het Excel-bestand met de koeigegevens',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Bestand kiezen'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Koennummer opzoeken',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: _searchKoe,
                decoration: InputDecoration(
                  hintText: 'Voer koennummer in (bijv. 6949)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: searchResults == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Zoek een koennummer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Geladen nummers: ${excelData.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (excelData.isNotEmpty)
                              Text(
                                'Bijv: ${excelData.keys.take(3).join(", ")}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : searchResults!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.not_interested,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Koennummer niet gevonden',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha(51),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Koe: ${searchController.text}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Stier adviezen:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            searchResults!.length,
                            (index) => _buildAdviceCard(
                              stierAdvice: searchResults![index],
                              advisIndex: index + 1,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildAdviceCard({
    required String stierAdvice,
    required int advisIndex,
  }) {
    final colors = [
      const Color(0xFF0066CC),
      const Color(0xFF00AA66),
      const Color(0xFFFF6600),
    ];
    
    final color = colors[advisIndex - 1];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$advisIndex',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advies stier $advisIndex',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stierAdvice,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
