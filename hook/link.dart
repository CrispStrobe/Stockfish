import 'package:hooks/hooks.dart';
import 'dart:io';

void main(List<String> args) async {
  await link(args, (input, output) async {
    final packageName = input.packageName;
    
    // Get the built dylib path from build output
    final buildOutput = input.dependenciesModel.dependencies
        .where((dep) => dep.package == packageName)
        .firstOrNull;
    
    if (buildOutput == null) {
      print('No build output found for $packageName');
      return;
    }

    // The dylib should be in the build output
    final builtAssets = buildOutput.encodedAssets;
    if (builtAssets.isEmpty) {
      print('No built assets found');
      return;
    }

    final dylibPath = builtAssets.first.file;
    print('Found dylib at: $dylibPath');

    // Create framework structure in the app bundle
    final recordedAssetFile = dylibPath.toFilePath();
    
    output.addEncodedAsset(
      EncodedAsset(
        package: packageName,
        name: 'stockfish.framework/stockfish',
        file: dylibPath,
      ),
    );
    
    print('Linked asset: stockfish.framework/stockfish -> $recordedAssetFile');
  });
}