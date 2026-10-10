package com.nourishly.app.nourishly

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException

/**
 * Serves the Navmaas share file (ADR-012, docs/navmaas-share.md), read-only,
 * at content://com.nourishly.app.nourishly.share/navmaas.
 *
 * Only apps holding com.patelkeyur.permission.NOURISHLY_SHARE get in, and
 * that is a signature permission: only apps signed with the owner's key
 * (ADR-011), which in practice is Navmaas. The file exists only while
 * Settings → Share with Navmaas is on.
 */
class ShareProvider : ContentProvider() {
    override fun onCreate() = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r" || uri.lastPathSegment != "navmaas") throw FileNotFoundException()
        val file = File(context!!.filesDir, "share/nourishly-share.json")
        if (!file.exists()) throw FileNotFoundException()
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri) = "application/json"

    // Read-only: nothing to query, insert, change or delete.
    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?) = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<String>?,
    ) = 0
}
