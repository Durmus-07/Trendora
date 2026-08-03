'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const readers = [
  ['newsApi', require('../routes/newsApi').createJsonSnapshotReader],
  ['news', require('../routes/news').createJsonSnapshotReader],
  ['opportunities', require('../routes/opportunities').createJsonSnapshotReader]
];

for (const [name, createReader] of readers) {
  test(`${name} snapshot cache reloads safely and shares concurrent reads`, async () => {
    const directory = await fs.promises.mkdtemp(
      path.join(os.tmpdir(), `trendora-${name}-`)
    );
    const filePath = path.join(directory, 'data.json');
    const originalReadFile = fs.promises.readFile;
    let readCount = 0;

    try {
      await fs.promises.writeFile(
        filePath,
        JSON.stringify({ version: 1, items: [{ id: 'first' }] }),
        'utf8'
      );

      fs.promises.readFile = async (...args) => {
        if (path.resolve(args[0]) === path.resolve(filePath)) readCount += 1;
        return originalReadFile(...args);
      };

      const snapshot = createReader(filePath, { version: 0, items: [] });
      const first = await snapshot.read();
      assert.equal(first.version, 1);
      assert.equal(readCount, 1);

      const second = await snapshot.read();
      assert.strictEqual(second, first);
      assert.equal(readCount, 1);

      const concurrent = await Promise.all([
        snapshot.read(),
        snapshot.read(),
        snapshot.read()
      ]);
      assert.ok(concurrent.every(item => item === first));
      assert.equal(readCount, 1);

      await originalReadFile(filePath, 'utf8');
      await fs.promises.writeFile(
        filePath,
        JSON.stringify({ version: 2, items: [{ id: 'second' }] }),
        'utf8'
      );
      const future = new Date(Date.now() + 2000);
      await fs.promises.utimes(filePath, future, future);

      const refreshed = await snapshot.read();
      assert.equal(refreshed.version, 2);
      assert.equal(readCount, 2);

      await fs.promises.writeFile(filePath, '{broken', 'utf8');
      const later = new Date(Date.now() + 4000);
      await fs.promises.utimes(filePath, later, later);

      const originalError = console.error;
      console.error = () => {};
      try {
        const fallback = await snapshot.read();
        assert.strictEqual(fallback, refreshed);
      } finally {
        console.error = originalError;
      }
      assert.equal(readCount, 3);
      assert.deepEqual(refreshed.items, [{ id: 'second' }]);

      await fs.promises.writeFile(filePath, 'null', 'utf8');
      const invalidRootTime = new Date(Date.now() + 6000);
      await fs.promises.utimes(filePath, invalidRootTime, invalidRootTime);
      const invalidRootError = console.error;
      console.error = () => {};
      try {
        assert.strictEqual(await snapshot.read(), refreshed);
      } finally {
        console.error = invalidRootError;
      }
      assert.equal(readCount, 4);

      await fs.promises.writeFile(
        filePath,
        JSON.stringify({ version: 3, items: [{ id: 'recovered' }] }),
        'utf8'
      );
      const recoveredTime = new Date(Date.now() + 8000);
      await fs.promises.utimes(filePath, recoveredTime, recoveredTime);
      const recovered = await snapshot.read();
      assert.equal(recovered.version, 3);
      assert.deepEqual(recovered.items, [{ id: 'recovered' }]);
      assert.equal(readCount, 5);
    } finally {
      fs.promises.readFile = originalReadFile;
      await fs.promises.rm(directory, { recursive: true, force: true });
    }
  });
}
