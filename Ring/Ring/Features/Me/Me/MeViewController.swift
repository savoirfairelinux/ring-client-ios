/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

import UIKit
import Reusable
import RxSwift
import RxCocoa
import RxDataSources

class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: - outlets
    @IBOutlet private weak var settingsTable: SettingsTableView!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()
    private var stretchyHeader: AccountHeader!

    // MARK: - functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addHeaderView()

        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.configureBindings()
        self.configureRingNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
    }

    private func addHeaderView() {
        guard let nibViews = Bundle.main
            .loadNibNamed("AccountHeader", owner: self, options: nil) else {
                supportEditProfile()
                return
        }
        guard let headerView = nibViews.first as? AccountHeader else {
            supportEditProfile()
            return
        }
        self.stretchyHeader = headerView
        self.settingsTable.addSubview(self.stretchyHeader)
        self.settingsTable.delegate = self
        self.profileImageView = stretchyHeader.profileImageView
        self.profileName = stretchyHeader.profileName
    }

    private func supportEditProfile() {
        // if loading grom nib failed add empty views requered by EditProfileViewController
        let image = UIImageView()
        let name = UITextField()
        self.view.addSubview(image)
        self.view.addSubview(name)
        self.profileImageView = image
        self.profileName = name
    }

    private func configureBindings() {
        let infoButton = UIButton(type: .infoLight)
        let infoItem = UIBarButtonItem(customView: infoButton)
        infoButton.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.infoItemTapped()
            })
            .disposed(by: self.disposeBag)

        self.navigationItem.rightBarButtonItem = infoItem

        //setup Table
        self.settingsTable.estimatedRowHeight = 50
        self.settingsTable.rowHeight = UITableViewAutomaticDimension
        self.settingsTable.tableFooterView = UIView()

        //Register cell
        self.setUpDataSource()
        self.settingsTable.register(cellType: DeviceCell.self)
        self.settingsTable.register(cellType: LinkNewDeviceCell.self)
        self.settingsTable.register(cellType: ProxyCell.self)
        self.settingsTable.register(cellType: BlockContactsCell.self)

        self.settingsTable.rx.itemSelected
            //.throttle(RxTimeInterval(2), scheduler: MainScheduler.instance)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] indexPath in
                if (self?.settingsTable.cellForRow(at: indexPath) as? BlockContactsCell) != nil {
                    self?.openBlockedList()
                    self?.settingsTable.deselectRow(at: indexPath, animated: true)
                }
            }).disposed(by: self.disposeBag)
    }

    private func openBlockedList() {
        self.viewModel.showBlockedContacts()
    }

    private func infoItemTapped() {
        var compileDate: String {
            let dateDefault = "20180131"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
            if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
                let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
                let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
                return dateFormatter.string(from: infoDate)
            }
            return dateDefault
        }
        let alert = UIAlertController(title: "\nRing\nbuild: \(compileDate)\n\"In varietate concordia\"", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        let image = UIImageView(image: UIImage(asset: Asset.ringIcon))
        alert.view.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        self.present(alert, animated: true, completion: nil)
    }

    private func setUpDataSource() {

        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, SettingsSection.Item)
            -> UITableViewCell = {
                ( dataSource: TableViewSectionedDataSource<SettingsSection>,
                tableView: UITableView,
                indexPath: IndexPath,
                item: SettingsSection.Item) in
                switch dataSource[indexPath] {

                case .device(let device):
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: DeviceCell.self)

                    cell.deviceIdLabel.text = device.deviceId
                    if let deviceName = device.deviceName {
                        cell.deviceNameLabel.text = deviceName
                    }
                    cell.selectionStyle = .none
                    return cell

                case .linkNew:
                    let cell = tableView.dequeueReusableCell(for: indexPath, cellType: LinkNewDeviceCell.self)

                    cell.addDeviceButton.rx.tap.subscribe(onNext: { [weak self] in
                        self?.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.addDeviceTitle.rx.tap.subscribe(onNext: { [weak self] in
                        self?.viewModel.linkDevice()
                    }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    return cell

                case .proxy:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                                                             cellType: ProxyCell.self)
                    cell.enableProxyLabel.text = L10n.Accountpage.enableProxy
                    cell.switchProxy.isOn = self.viewModel.proxyInitialState
                    self.viewModel.proxyEnabled?
                        .observeOn(MainScheduler.instance)
                        .bind(to: cell.switchProxy.rx.isOn)
                        .disposed(by: cell.disposeBag)
                    cell.switchProxy.rx.value.skip(1)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] (enable) in
                            self?.viewModel.enableProxy(enable: enable)
                        }).disposed(by: cell.disposeBag)
                    cell.selectionStyle = .none
                    return cell

                case .blockedList:
                    let cell = tableView.dequeueReusableCell(for: indexPath,
                    cellType: BlockContactsCell.self)
                    cell.label.text = L10n.Accountpage.blockedContacts
                    return cell

                case .sectionHeader(let title):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = title
                    cell.backgroundColor = UIColor.ringNavigationBar.darken(byPercentage: 0.02)
                    cell.selectionStyle = .none
                    return cell

                case .ordinary(let label):
                    let cell = UITableViewCell()
                    cell.textLabel?.text = label
                    cell.selectionStyle = .none
                    return cell
                }
        }

        let settingsItemDataSource = RxTableViewSectionedReloadDataSource<SettingsSection>(configureCell: configureCell)
        self.viewModel.settings
            .bind(to: self.settingsTable.rx.items(dataSource: settingsItemDataSource))
            .disposed(by: disposeBag)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetProfileName()
        self.profileName.resignFirstResponder()
    }
}

extension MeViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationController?.navigationBar.bounds.height
        var size = self.view.bounds.size
        let screenSize = UIScreen.main.bounds.size
        if let height = navigationHeight {
            //height for ihoneX
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone,
                screenSize.height == 812.0 {
                size.height -= (height - 10)
            }
        }
        if scrollView.contentSize.height < size.height {
            scrollView.contentSize = size
        }

        // hide keebord if it was open when user performe scrolling
        if self.stretchyHeader.frame.height < self.stretchyHeader.maximumContentHeight * 0.5 {
            resetProfileName()
            self.profileName.resignFirstResponder()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollViewDidStopScrolling()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.scrollViewDidStopScrolling()
        }
    }

    private func scrollViewDidStopScrolling() {
        var contentOffset = self.settingsTable.contentOffset
        if self.stretchyHeader.frame.height <= self.stretchyHeader.minimumContentHeight {
            return
        }
        let middle = (self.stretchyHeader.maximumContentHeight - self.stretchyHeader.minimumContentHeight) * 0.4
        if self.stretchyHeader.frame.height > middle {
            contentOffset.y = -self.stretchyHeader.maximumContentHeight
        } else {
            contentOffset.y = -self.stretchyHeader.minimumContentHeight
        }
        self.settingsTable.setContentOffset(contentOffset, animated: true)
    }
}
