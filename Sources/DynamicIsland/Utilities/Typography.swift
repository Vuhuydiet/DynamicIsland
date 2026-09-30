import SwiftUI

public enum IslandFont {
    /// 1. Primary Card Title (e.g. Song Title, Section Title, Main Headers)
    public static let title = Font.system(size: 13, weight: .bold)
    
    /// 2. Secondary Label / Subtitle (e.g. Artist, Category names, Mode labels)
    public static let subtitle = Font.system(size: 11, weight: .medium)
    
    /// 3. Body text (e.g. Notes editor, Search field, Clipboard items)
    public static let body = Font.system(size: 11, weight: .regular)
    
    /// 4. Compact Ear Text / Tab Bar Labels / Button Labels
    public static let caption = Font.system(size: 10, weight: .semibold)
    
    /// 5. Micro Labels (e.g. "RUNNING" state, file sizes, tiny badges)
    public static let micro = Font.system(size: 9, weight: .medium)
    
    /// 6. Hero Numerical Readout (Timer countdown & Stopwatch display)
    public static let heroNumeric = Font.system(size: 22, weight: .bold, design: .monospaced)
    
    /// 7. Metric / Gauge Readouts (CPU load, RAM used, Battery percentage)
    public static let metricNumeric = Font.system(size: 11, weight: .bold, design: .rounded)
    
    /// 8. Scrubber & Time Elapsed Readouts (01:45, 03:20)
    public static let timeNumeric = Font.system(size: 10, weight: .medium, design: .monospaced)
    
    /// 9. Standard Icon Sizes
    public static let iconHero = Font.system(size: 20, weight: .bold)
    public static let iconLarge = Font.system(size: 16, weight: .semibold)
    public static let iconRegular = Font.system(size: 12, weight: .semibold)
    public static let iconSmall = Font.system(size: 10, weight: .bold)
    public static let iconMicro = Font.system(size: 9, weight: .semibold)
}
