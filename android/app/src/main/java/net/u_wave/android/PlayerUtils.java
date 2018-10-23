package net.u_wave.android;

class PlayerUtils {
  public static String getNewPipeSourceName(String sourceType) {
    if (sourceType.equals("youtube")) return "YouTube";
    if (sourceType.equals("soundcloud")) return "SoundCloud";
    return null;
  }

  public static String getNewPipeSourceUrl(String sourceType, String sourceID) {
    if (sourceType.equals("youtube")) {
      return "https://youtube.com/watch?v=" + sourceID;
    }
    if (sourceType.equals("soundcloud")) {
      return "https://api.soundcloud.com/tracks/" + sourceID;
    }
    return null;
  }
}
