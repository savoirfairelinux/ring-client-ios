/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import Contacts

class EditProfileViewModel {

    let disposeBag = DisposeBag()
    let defaultImage = UIImage(named: "add_avatar")
    var image: UIImage?
    var name: String = ""
    let profileService: ProfilesService
    let accountService: AccountsService

    lazy var profileImage: Observable<UIImage?> = { [unowned self] in
        guard let account = self.accountService.currentAccount,
            let jamiId = AccountModelHelper
                .init(withAccount: account)
                .ringId else {
                    return Observable.just(defaultImage)
        }
        return self.profileService.getProfile(ringId: jamiId)
            .map({ profile in
                if let photo = profile.photo,
                let data = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.image = UIImage(data: data)
                    return  UIImage(data: data)
                }
                return self.defaultImage
            })
    }()

    lazy var profileName: Observable<String?> = { [unowned self] in
        guard let account = self.accountService.currentAccount,
            let jamiId = AccountModelHelper
                .init(withAccount: account)
                .ringId else {
                    return Observable.just("")
        }
        return self.profileService.getProfile(ringId: jamiId)
            .map({ profile in
                if let alias = profile.alias, !alias.isEmpty {
                    self.name = alias
                    return alias
                }
                return ""
            })
    }()

    init(profileService: ProfilesService, accountService: AccountsService) {
        self.profileService = profileService
        self.accountService = accountService
      }

    func saveProfile() {
        guard let account = self.accountService.currentAccount,
        let jamiId = AccountModelHelper.init(withAccount: account).ringId else {return}
        let vcard = CNMutableContact()
        if let image = self.image, !image.isEqual(defaultImage) {
            vcard.imageData = UIImagePNGRepresentation(image)
        }
        vcard.familyName = self.name
        self.profileService.updateProfile(accountId: account.id,
                                          profileUri: jamiId,
                                          isAccount: true,
                                          vCard: vcard)
    }

    func updateImage(_ image: UIImage) {
        self.image = image
        self.saveProfile()
    }

    func updateName(_ name: String) {
        self.name = name
        self.saveProfile()
    }
}
