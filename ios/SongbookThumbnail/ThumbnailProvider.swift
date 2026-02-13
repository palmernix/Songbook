//
//  ThumbnailProvider.swift
//  SongbookThumbnail
//
//  Created by Palmer Harrison Wright Nix on 2/13/26.
//

import UIKit
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize

        let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: {
            guard let url = Bundle.main.url(forResource: "DocumentIcon", withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                return false
            }
            image.draw(in: CGRect(origin: .zero, size: size))
            return true
        })

        handler(reply, nil)
    }
}
