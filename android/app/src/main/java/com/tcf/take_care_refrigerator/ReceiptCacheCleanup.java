package com.tcf.take_care_refrigerator;
import java.io.File;
/** Legacy entry point disabled: a selected path is not proof of ownership. */
public final class ReceiptCacheCleanup {
  private ReceiptCacheCleanup() {}
  public static boolean deleteSelectedCacheFile(File ignored, String path) { return false; }
}
