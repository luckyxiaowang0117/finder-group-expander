import Foundation

struct VolumeInfo: Identifiable, Hashable {
    /// 挂载路径，如 /Volumes/gutai 或 /（启动盘）
    let id: String
    let name: String
    let path: String
    let isRemovable: Bool
    let isInternal: Bool
    let uuid: String?

    var preferenceKey: String {
        if let uuid { return "uuid:\(uuid)" }
        return "path:\(path)"
    }
}

enum VolumeScanner {
    /// 扫描本机所有已挂载的硬盘：启动盘 + /Volumes 下的外置盘 / U盘。
    /// 系统隐藏卷会被跳过。
    static func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeUUIDStringKey]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var result: [VolumeInfo] = []
        for url in urls {
            let path = url.path
            guard path == "/" || path.hasPrefix("/Volumes/") else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = values?.volumeName ?? url.lastPathComponent
            guard !name.isEmpty else { continue }
            result.append(VolumeInfo(
                id: path,
                name: name,
                path: path,
                isRemovable: values?.volumeIsRemovable ?? false,
                isInternal: values?.volumeIsInternal ?? true,
                uuid: values?.volumeUUIDString
            ))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 判断一个文件夹路径属于哪块硬盘（按最长挂载路径前缀匹配）。
    static func volumeContaining(path: String, in volumes: [VolumeInfo]) -> VolumeInfo? {
        var best: VolumeInfo?
        for volume in volumes {
            if volume.path == "/" {
                if path.hasPrefix("/") && best == nil {
                    best = volume
                }
            } else if path == volume.path || path.hasPrefix(volume.path + "/") {
                if let current = best {
                    if volume.path.count > current.path.count {
                        best = volume
                    }
                } else {
                    best = volume
                }
            }
        }
        return best
    }
}
