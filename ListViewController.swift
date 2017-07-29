//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"https://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  
  var photos = [PhotoRecord]()
  let pendingOperations = PendingOperations()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    fetchPhotoDetails()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // #pragma mark - Table view data source
  
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
    
    //1
    if cell.accessoryView == nil {
      let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
      cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    //2
    let photoDetails = photos[indexPath.row]
    
    //3
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    //4
    switch (photoDetails.state){
    case .Filtered:
      indicator.stopAnimating()
    case .Failed:
      indicator.stopAnimating()
      cell.textLabel?.text = "Failed to load"
    case .New, .Downloaded:
      indicator.startAnimating()
      self.startOperationsForPhotoRecord(photoDetails: photoDetails,indexPath:indexPath as NSIndexPath)
    }
    
    return cell
  }
  
  func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    switch (photoDetails.state) {
    case .New:
      startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
    case .Downloaded:
      startFiltrationForRecord(photoDetails: photoDetails, indexPath: indexPath)
    default:
      NSLog("do nothing")
    }
  }
  
  func fetchPhotoDetails() {
    let request = NSURLRequest(url:dataSourceURL!)
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main) {response,data,error in
      if data != nil {
        do {
        let datasourceDictionary = try PropertyListSerialization.propertyList(from: data!, options:[], format: nil) as! NSDictionary
          
          for(key,value) in datasourceDictionary {
            let name = key as? String
            let url = NSURL(string:value as? String ?? "")
            if url != nil {
              let photoRecord = PhotoRecord(name:name!, url:url!)
              self.photos.append(photoRecord)
            }
          }
          
        } catch {
          print(error)
        }
        
        self.tableView.reloadData()
      }
      
      if error != nil {
        let alert = UIAlertView(title:"Oops!",message:error?.localizedDescription, delegate:nil, cancelButtonTitle:"OK")
        alert.show()
      }
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }
  
  func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    //1
    if pendingOperations.downloadsInProgress[indexPath] != nil {
      return
    }
    
    //2
    let downloader = ImageDownloader(photoRecord: photoDetails)
    //3
    downloader.completionBlock = {
      if downloader.isCancelled {
        return
      }
      DispatchQueue.main.async(execute: {
        self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
      })
    }
    //4
    pendingOperations.downloadsInProgress[indexPath] = downloader
    //5
    pendingOperations.downloadQueue.addOperation(downloader)
  }
  
  func startFiltrationForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    if pendingOperations.filtrationsInProgress[indexPath] != nil{
      return
    }
    
    let filterer = ImageFiltration(photoRecord: photoDetails)
    filterer.completionBlock = {
      if filterer.isCancelled {
        return
      }
      DispatchQueue.main.async(execute: {
        self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
      })
    }
    pendingOperations.filtrationsInProgress[indexPath] = filterer
    pendingOperations.filtrationQueue.addOperation(filterer)
  }
  
}
