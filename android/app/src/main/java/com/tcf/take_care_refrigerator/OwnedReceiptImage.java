package com.tcf.take_care_refrigerator;

import java.io.File;
import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.BasicFileAttributeView;

/** API 26+ only. One opaque owner per OCR job. Never deletes the selected input.
 * Cleanup requires an anchored SecureDirectoryStream and stable file identity;
 * unsupported filesystems leave the private copy in cache. No recursive delete.
 */
public final class OwnedReceiptImage {
  private final Path directory, image;
  private final DirectoryStream<Path> handle;
  private final Object imageKey;
  private boolean closed;
  private OwnedReceiptImage(Path directory, Path image, DirectoryStream<Path> handle, Object key) {
    this.directory=directory; this.image=image; this.handle=handle; this.imageKey=key;
  }
  public File getFile() { return image.toFile(); }
  public static OwnedReceiptImage create(File cache, String selected) throws IOException {
    // Allocate a private random directory, never reuse caller-supplied paths.
    Path directory=Files.createTempDirectory(cache.toPath().toRealPath(), "receipt-ocr-owned-");
    DirectoryStream<Path> handle=Files.newDirectoryStream(directory);
    try {
      Path image=directory.resolve("input.img");
      Files.copy(new File(selected).toPath(), image); // no overwrite option
      Object key=Files.readAttributes(image,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS).fileKey();
      return new OwnedReceiptImage(directory,image,handle,key);
    } catch (IOException | RuntimeException error) {
      // A failed allocation/copy can leave cache, but never delete uncertain data.
      handle.close();
      throw error;
    }
  }
  public synchronized boolean cleanup() {
    if (closed) return false;
    closed=true;
    try {
      if (!(handle instanceof SecureDirectoryStream) || imageKey==null) return false;
      SecureDirectoryStream<Path> owned=(SecureDirectoryStream<Path>)handle;
      Path name=image.getFileName();
      BasicFileAttributes current=owned.getFileAttributeView(name,
          BasicFileAttributeView.class,LinkOption.NOFOLLOW_LINKS).readAttributes();
      if (!current.isRegularFile() || !imageKey.equals(current.fileKey())) return false;
      // Relative unlink on the retained directory handle cannot follow a swapped
      // parent path or symlink target. Each job has a separate retained handle.
      owned.deleteFile(name);
      return true;
    } catch (IOException | RuntimeException ignored) {
      return false;
    } finally {
      try { handle.close(); } catch (IOException ignored) {}
      // Empty job directory intentionally retained; never path-delete a parent.
    }
  }
}
