'use strict';

const { ASSET_CATALOG } = require('./assetCatalog');

const assetsById = new Map(
  ASSET_CATALOG.map(asset => [asset.internalAssetId, asset])
);

function resolveAsset(assetOrId) {
  if (!assetOrId) return null;
  if (typeof assetOrId === 'string') return assetsById.get(assetOrId) || null;
  if (assetOrId.internalAssetId && assetOrId.providerSymbols) return assetOrId;
  if (assetOrId.internalAssetId) return assetsById.get(assetOrId.internalAssetId) || null;
  return null;
}

function resolveProviderSymbol(assetOrId, providerName) {
  const asset = resolveAsset(assetOrId);
  const provider = String(providerName || '').trim().toLowerCase();
  if (!asset || !provider) return null;
  const value = asset.providerSymbols?.[provider];
  return value ? String(value) : null;
}

module.exports = {
  resolveProviderSymbol
};
