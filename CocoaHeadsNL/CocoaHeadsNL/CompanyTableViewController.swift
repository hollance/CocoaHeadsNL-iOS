//
//  CompanyTableViewController.swift
//  CocoaHeadsNL
//
//  Created by Bart Hoffman on 30/05/15.
//  Copyright (c) 2016 Stichting CocoaheadsNL. All rights reserved.
//

import Foundation
import UIKit
import CloudKit
import Crashlytics

class CompanyTableViewController: UITableViewController {

    var sortedArray = [(place: String, companies:[Company])]()
    @IBOutlet weak var sortingLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewWillAppear(animated: Bool) {
        self.fetchCompanies()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backItem = UIBarButtonItem(title: "Companies", style: .Plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem

        self.navigationItem.titleView = UIImageView(image: UIImage(named: "Banner")!)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CompanyTableViewController.locationAvailable(_:)), name: "LOCATION_AVAILABLE", object: nil)

        self.subscribe()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        Answers.logContentViewWithName("Show companies",
                                       contentType: "Company",
                                       contentId: "overview",
                                       customAttributes: nil)
    }

    func locationAvailable(notification: NSNotification) -> Void {

        let userInfo = notification.userInfo as! Dictionary<String, CLLocation>

        print("CoreLocationManager:  Location available \(userInfo)")

        if let _ = userInfo["location"]?.coordinate.latitude, _ = userInfo["location"]?.coordinate.longitude {
            self.sortingLabel?.text = "Companies sorted by distance"
        } else {
            self.sortingLabel?.text = "Companies sorted by name"
        }
    }


    //MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowCompanies" {
            if let indexPath = self.tableView.indexPathForCell(sender as! UITableViewCell) {

                let detailViewController = segue.destinationViewController as? LocatedCompaniesViewController
                detailViewController?.companyDict = sortedArray[indexPath.row]

                Answers.logContentViewWithName("Show company location",
                                               contentType: "Company",
                                               contentId: sortedArray[indexPath.row].place,
                                               customAttributes: nil)
            }
        }
    }

    //MARK: - UITablewViewDelegate

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedArray.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Companies sorted by city"
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let labelRect = CGRect(x: 15, y: 2, width: 300, height: 18)
        let label = UILabel(frame: labelRect)
        label.font = UIFont.boldSystemFontOfSize(15)

        label.text = tableView.dataSource!.tableView!(tableView, titleForHeaderInSection: section)

        let viewRect = CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.sectionHeaderHeight)
        let view = UIView(frame: viewRect)
        view.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1)
        view.addSubview(label)

        return view
    }


    //MARK: - UITableViewDataSource


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCellWithIdentifier("companyTableViewCell", forIndexPath: indexPath)


        cell.textLabel!.text = sortedArray[indexPath.row].place


        return cell
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44
    }

    //MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("ShowCompanies", sender: tableView.cellForRowAtIndexPath(indexPath))
    }

    //MARK: - Notifications

    func subscribe() {
        let publicDB = CKContainer.defaultContainer().publicCloudDatabase

        let subscription = CKSubscription(
            recordType: "Companies",
            predicate: NSPredicate(value: true),
            options: .FiresOnRecordCreation
        )

        let info = CKNotificationInfo()

        info.alertBody = "A new company has been added!"
        info.shouldBadge = true

        subscription.notificationInfo = info

        publicDB.saveSubscription(subscription) { record, error in }
    }

    //MARK: - fetching Cloudkit

    func fetchCompanies() {

        let pred = NSPredicate(value: true)
        let sort = NSSortDescriptor(key: "name", ascending: false)
        let query = CKQuery(recordType: "Companies", predicate: pred)
        query.sortDescriptors = [sort]

        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .UserInteractive

        var companies = [Company]()

        operation.recordFetchedBlock = { (record) in
            let company = Company(record: record)
            let _ = company.smallLogoImage
            let _ = company.logoImage

            companies.append(company)
        }

        operation.queryCompletionBlock = { [weak self] (cursor, error) in
            dispatch_async(dispatch_get_main_queue()) {
                if error == nil {

                    self?.sortedArray.removeAll()

                    var locationSet = Set<String>()

                    for company in companies {

                        if let location = company.place {

                            if !locationSet.contains(location) {
                                locationSet.insert(location)
                            }
                        }
                    }

                    let groupedArray = locationSet.sort()

                    for group in groupedArray {
                        var companyArray = [Company]()

                        for company in companies {
                            if let loc = company.place where loc == group {
                                    companyArray.append(company)
                            }
                        }

                        let companiesForPlace = (place: group, companies:companyArray)

                        self?.sortedArray.append(companiesForPlace)
                    }
                    self?.tableView.reloadData()
                } else {
                    let ac = UIAlertController(title: "Fetch failed", message: "There was a problem fetching the list of companies; please try again: \(error!.localizedDescription)", preferredStyle: .Alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                    self?.presentViewController(ac, animated: true, completion: nil)
                }
            }
        }

        CKContainer.defaultContainer().publicCloudDatabase.addOperation(operation)
    }
}
