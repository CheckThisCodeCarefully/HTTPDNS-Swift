//
//  HTTPDNS.swift
//  HTTPDNS-SwiftDemo
//
//  Created by YourtionGuo on 12/4/15.
//  Copyright © 2015 Yourtion. All rights reserved.
//

import Foundation

public struct DNSRecord {
    public let ip : String
    let ttl : Int
    public let ips : Array<String>
    let timeout : Int
    public let cached : Bool
}

public class HTTPDNS {
    let SERVER_ADDRESS = "http://119.29.29.29/"
    var cache = Dictionary<String,DNSRecord>()
    
    public static let sharedInstance = HTTPDNS()
    
    private init() {}
    
    public func getRecord(domain: String, callback: (result:DNSRecord!) -> Void) {
        let res = getCacheResult(domain)
        if (res != nil) {
            return callback(result: res)
        }
        requsetRecord(domain, callback: { (res) -> Void in
            callback(result: res)
        })
    }
    
    /**
     Get DNS record sync (if not exist in cache return nil)
     
     - parameter domain: domain name
     
     - returns: DSN record
     */
    public func getRecordSync(domain: String) -> DNSRecord! {
        guard let res = getCacheResult(domain) else {
            return requsetRecordSync(domain)
        }
        return res
    }
    
    func setCache(domain: String, record: DNSRecord) {
        let res = DNSRecord.init(ip: record.ip, ttl: record.ttl, ips: record.ips, timeout: record.timeout, cached: true)
        self.cache.updateValue(res, forKey:domain)
    }
    
    func getCacheResult(domain: String) -> DNSRecord! {
        guard let res = self.cache[domain] else {
            return nil
        }
        if (res.timeout <= getSecondTimestamp()){
            self.cache.removeValueForKey(domain)
            return nil
        }
        return res
    }
    
    public func cleanCache() {
        self.cache.removeAll()
    }
    
    func getRequestString(domain: String) -> String {
        return self.SERVER_ADDRESS + "d?dn=" + domain + "&ttl=1"
    }
    
    func requsetRecord(domain: String, callback: (result:DNSRecord!) -> Void) {
        let urlString = getRequestString(domain)
        guard let url = NSURL(string: urlString) else {
            print("Error: cannot create URL")
            return
        }
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url) {(data, response, error) in
            print(NSString(data: data!, encoding: NSUTF8StringEncoding))
            guard let responseData = data else {
                print("Error: Didn't receive data")
                return
            }
            guard error == nil else {
                print("Error: Calling GET error on " + urlString)
                print(error)
                return
            }
            guard let res = self.parseResult(responseData) else {
                return callback(result: nil)
            }
            self.setCache(domain, record: res)
            callback(result: res)
        }
        task.resume()
    }
    
    func requsetRecordSync(domain: String) -> DNSRecord! {
        let urlString = getRequestString(domain)
        guard let url = NSURL(string: urlString) else {
            print("Error: Can't create URL")
            return nil
        }
        guard let data = NSData.init(contentsOfURL: url) else {
            print("Error: Did not receive data")
            return nil
        }
        guard let res = self.parseResult(data) else {
            print("Error: ParseResult error")
            return nil
        }
        setCache(domain, record: res)
        return res
    }
    
    func getSecondTimestamp() -> Int {
        return Int(NSDate().timeIntervalSince1970 * 1000)
    }
    
    func parseResult (data: NSData) -> DNSRecord! {
        let str = String(data: data, encoding: NSUTF8StringEncoding)
        let strArray = str!.componentsSeparatedByString(",")
        let ipStr = strArray[0] as String
        let ipList = ipStr.componentsSeparatedByString(";") as Array<String>
        guard let ttl = Int(strArray[1]) where (ipList.count > 0 && ttl > 0) else {
            return nil
        }
        let timeout = getSecondTimestamp() + ttl
        return DNSRecord.init(ip: ipList[0], ttl: ttl, ips: ipList, timeout: timeout, cached: false)
    }
}