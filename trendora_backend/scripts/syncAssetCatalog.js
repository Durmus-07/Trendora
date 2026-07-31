'use strict';

const {
  runAssetCatalogSync
} = require('../services/assets/assetCatalogSyncService');

function parseArgs(argv) {
  const args = new Set(argv.slice(2));
  return {
    mode: args.has('--apply') ? 'apply' : 'dry-run',
    writeReport: args.has('--write-report') || args.has('--apply'),
    silent: args.has('--json')
  };
}

function compactResult(result) {
  return {
    status: result.status,
    mode: result.mode,
    changed: result.changed,
    durationMs: result.durationMs,
    bist: {
      sourceCount: result.bist.sourceCount,
      catalogCount: result.bist.catalogCount,
      added: result.bist.added.map(item => item.canonicalSymbol),
      missingFromSource: result.bist.missingFromSource.map(item => item.canonicalSymbol),
      metadataChanged: result.bist.metadataChanged.map(item => item.canonicalSymbol),
      conflicts: result.bist.conflicts
    },
    tefas: {
      sourceCount: result.tefas.sourceCount,
      catalogCount: result.tefas.catalogCount,
      added: result.tefas.added.map(item => item.canonicalSymbol),
      missingFromSource: result.tefas.missingFromSource.map(item => item.canonicalSymbol),
      metadataChanged: result.tefas.metadataChanged.map(item => item.canonicalSymbol),
      conflicts: result.tefas.conflicts
    },
    reportPath: result.reportPath,
    errors: result.errors
  };
}

async function main() {
  const options = parseArgs(process.argv);
  const result = await runAssetCatalogSync({
    mode: options.mode,
    writeReport: options.writeReport,
    logger: options.silent ? false : console
  });

  console.log(JSON.stringify(compactResult(result), null, 2));

  if (result.status === 'failed' || result.status === 'degraded') {
    process.exitCode = 1;
  }
}

main().catch(error => {
  console.error('[AssetCatalogSync] manuel çalıştırma hatası:', error?.stack || error);
  process.exitCode = 1;
});
