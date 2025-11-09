// -----------------------------------------------------------------------------
//  lib/services/file_helpers_mobile.dart
//  Centraliza e simplifica o acesso a arquivos locais e diretórios
//  ✅ Feito para iOS/macOS (não necessário em Web)
// -----------------------------------------------------------------------------

import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Reexporta apenas as classes e funções realmente necessárias
export 'dart:io' show File, Directory, Platform;
export 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
