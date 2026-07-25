//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK

// WINCAT: declared under the fork-private name; the `FileManagerDelegate`
// spelling is a typealias whose visibility is conditional (see
// SwiftFileManager.swift). Under WINCAT_OBJC_FILEMANAGER the public name is
// vacated so the ObjC NSFileManagerDelegate can own the Apple spelling.
public protocol _FEFileManagerDelegate : AnyObject, Sendable {
    // String-based requirements
    func fileManager(_ fileManager: _FEFileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldRemoveItemAtPath path: String) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, removingItemAtPath path: String) -> Bool
    
    // URL-based requirements
    func fileManager(_ fileManager: _FEFileManager, shouldCopyItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, copyingItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldMoveItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldLinkItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, linkingItemAt srcURL: URL, to dstURL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldRemoveItemAt URL: URL) -> Bool
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, removingItemAt URL: URL) -> Bool
}

// Default implementations for String-based requirements
extension _FEFileManagerDelegate {
    func fileManager(_ fileManager: _FEFileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: _FEFileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: _FEFileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: _FEFileManager, shouldRemoveItemAtPath path: String) -> Bool { return true }
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, removingItemAtPath path: String) -> Bool { return false }
}

// Default implementations for URL-based requirements
extension _FEFileManagerDelegate {
    func fileManager(_ fileManager: _FEFileManager, shouldCopyItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldCopyItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, copyingItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldProceedAfterError: error, copyingItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldMoveItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldMoveItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldProceedAfterError: error, movingItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldLinkItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldLinkItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, linkingItemAt srcURL: URL, to dstURL: URL) -> Bool {
        self.fileManager(fileManager, shouldProceedAfterError: error, linkingItemAtPath: srcURL.relativePath, toPath: dstURL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldRemoveItemAt URL: URL) -> Bool {
        self.fileManager(fileManager, shouldRemoveItemAtPath: URL.relativePath)
    }
    
    func fileManager(_ fileManager: _FEFileManager, shouldProceedAfterError error: Error, removingItemAt URL: URL) -> Bool {
        self.fileManager(fileManager, shouldProceedAfterError: error, removingItemAtPath: URL.relativePath)
    }
}

#endif
