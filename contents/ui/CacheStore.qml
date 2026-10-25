/*
    SPDX-FileCopyrightText: 2026 izll
    SPDX-FileCopyrightText: 2026 Gabriel A. Devenyi
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.LocalStorage

// Usage cache in LocalStorage (SQLite), one JSON value per key. Loaded through
// a Loader: on distributions that ship QtQuick.LocalStorage as a separate
// package (Debian, Ubuntu) it may be missing, and the widget then keeps the
// cache in its config instead.
Item {
    id: store

    property string dbName

    function db() {
        var d = LocalStorage.openDatabaseSync(store.dbName, "", "Usage widget cache", 1000000)
        d.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(key TEXT PRIMARY KEY, value TEXT)")
        })
        return d
    }

    function read(key) {
        var value = ""
        try {
            db().readTransaction(function(tx) {
                var rs = tx.executeSql("SELECT value FROM kv WHERE key = ?", [key])
                if (rs.rows.length > 0) value = rs.rows.item(0).value
            })
        } catch (e) {
            console.log("Cache read error:", e)
        }
        return value
    }

    function write(key, value) {
        try {
            db().transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO kv(key, value) VALUES(?, ?)", [key, value])
            })
            return true
        } catch (e) {
            console.log("Cache write error:", e)
            return false
        }
    }

    function remove(key) {
        try {
            db().transaction(function(tx) {
                tx.executeSql("DELETE FROM kv WHERE key = ?", [key])
            })
        } catch (e) {
            console.log("Cache delete error:", e)
        }
    }
}
