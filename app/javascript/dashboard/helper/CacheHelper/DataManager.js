import { openDB } from 'idb';
import { DATA_VERSION } from './version';

const OPEN_TIMEOUT_MS = 3000;

export class DataManager {
  constructor(accountId) {
    this.modelsToSync = ['inbox', 'label', 'team'];
    this.accountId = accountId;
    this.db = null;
  }

  async initDb() {
    if (this.db) return this.db;
    const dbName = `cw-store-${this.accountId}`;
    let openedDb = null;
    const openRequest = openDB(dbName, DATA_VERSION, {
      upgrade(upgradeDb) {
        upgradeDb.createObjectStore('cache-keys');
        upgradeDb.createObjectStore('inbox', { keyPath: 'id' });
        upgradeDb.createObjectStore('label', { keyPath: 'id' });
        upgradeDb.createObjectStore('team', { keyPath: 'id' });
      },
      // Logout in another tab deletes this DB; an open connection here would block that delete
      // forever and every later open (in all tabs) would hang behind it, so release it and reopen on demand.
      blocking: () => {
        openedDb?.close();
        if (this.db === openedDb) this.db = null;
      },
      terminated: () => {
        if (this.db === openedDb) this.db = null;
      },
    }).then(db => {
      openedDb = db;
      return db;
    });

    // An open stuck behind a connection held elsewhere never settles; give up so callers fall back to the network.
    let timedOut = false;
    const timeout = new Promise((_, reject) => {
      setTimeout(() => {
        timedOut = true;
        reject(new Error('IndexedDB open timed out'));
      }, OPEN_TIMEOUT_MS);
    });
    openRequest
      .then(db => {
        if (timedOut) db.close();
      })
      .catch(() => {});

    this.db = await Promise.race([openRequest, timeout]);

    // Store the database name in LocalStorage
    const dbNames = JSON.parse(localStorage.getItem('cw-idb-names') || '[]');
    if (!dbNames.includes(dbName)) {
      dbNames.push(dbName);
      localStorage.setItem('cw-idb-names', JSON.stringify(dbNames));
    }

    return this.db;
  }

  validateModel(name) {
    if (!name) throw new Error('Model name is not defined');
    if (!this.modelsToSync.includes(name)) {
      throw new Error(`Model ${name} is not defined`);
    }
    return true;
  }

  async replace({ modelName, data }) {
    this.validateModel(modelName);

    this.db.clear(modelName);
    return this.push({ modelName, data });
  }

  async push({ modelName, data }) {
    this.validateModel(modelName);

    if (Array.isArray(data)) {
      const tx = this.db.transaction(modelName, 'readwrite');
      data.forEach(item => {
        tx.store.add(item);
      });
      await tx.done;
    } else {
      await this.db.add(modelName, data);
    }
  }

  async get({ modelName }) {
    this.validateModel(modelName);
    return this.db.getAll(modelName);
  }

  async setCacheKeys(cacheKeys) {
    Object.keys(cacheKeys).forEach(async modelName => {
      this.db.put('cache-keys', cacheKeys[modelName], modelName);
    });
  }

  async getCacheKey(modelName) {
    this.validateModel(modelName);

    return this.db.get('cache-keys', modelName);
  }
}
