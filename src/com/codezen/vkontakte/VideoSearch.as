package com.codezen.vkontakte
{
	import com.codezen.helper.Worker;
	import com.codezen.util.CUtils;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.system.System;
	import flash.utils.escapeMultiByte;
	import flash.utils.unescapeMultiByte;
	
	import flashx.textLayout.utils.CharacterUtil;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	import mx.utils.object_proxy;

	/**
	 * 
	 * @author yamalight
	 * 
	 * Vkontakte music search class
	 * Returns one found song for request
	 * 
	 * USAGE:
	 * var s:MusicSearch = new MusicSearch('login','pass');
	 * s.addEventListener(Worker.COMPLETE, onLinkFound);
	 * s.init();
	 * s.findData('Muse Intro');
	 * 
	 */
	public class VideoSearch extends Worker
	{
		// login and passwork for auth
		private var login_mail:String;
		private var login_pass:String;
		
		// result of search
		private var results:ArrayCollection;
		
		// hd def array
		private var hdDef:Array = [
			["1", "360"],
			["2", "480"],
			["3", "720"]
		];
		
		// loader and request
		private var urlRequest:URLRequest;
		private var myLoader:URLLoader;
		
		// limit of duration
		private var finddur:int;
		
		private var data:String;
		
		/**
		 * 
		 * @param login - login for vkontakte.ru
		 * @param pass - password for vkontakte.ru
		 *
		 * Class constructor, sets login and password
		 */
		public function VideoSearch(login:String, pass:String)
		{
			// save login and password
			login_mail = login;
			login_pass = pass;
			
			// init request and loader
			urlRequest = new URLRequest();
			myLoader = new URLLoader();
			// set params and add error event listener
			urlRequest.requestHeaders['Referer'] = "http://vkontakte.ru/";
			myLoader.dataFormat = URLLoaderDataFormat.TEXT;
			myLoader.addEventListener(IOErrorEvent.IO_ERROR, onError);
		}
		
		/**
		 * 
		 * @return (Array) results of search 
		 * 
		 */
		public function get resultArray():ArrayCollection{
			return results;
		}
		
		/**
		 * Initializes class: checks if user already logged in 
		 * and if not - logs in.
		 * Must be executed before search 
		 */
		public function init():void{
			// init request
			urlRequest.url = "http://vkontakte.ru/";
			// add event listener and load url
			myLoader.addEventListener(Event.COMPLETE, onCheckLogin);
			myLoader.load(urlRequest);
		}
		
		/**
		 * 
		 * @param e
		 * 
		 * On recieve index page of vkontakte.ru
		 */
		private function onCheckLogin(e:Event):void{
			// remove event litener
			myLoader.removeEventListener(Event.COMPLETE, onCheckLogin);
			// close loader
			//myLoader.close();
			
			// get data
			var data:String = myLoader.data;
			
			// check if logged in
			if(data.match('id="myfriends"') == null){
				doLogin();
			}else{
				dispatchEvent(new Event(Worker.INITIALIZED));
			}
			
			data = null;
		}
		
		/**
		 * Function that does log in to vkontakte.ru 
		 */
		private function doLogin():void{
			// create urlrequester and urlloader
			urlRequest.url = "http://vkontakte.ru/login.php?email="+
				escapeMultiByte(login_mail)+"&pass="+
				escapeMultiByte(login_pass)+"&expire=1";
			
			// add event listener and load url
			myLoader.addEventListener(Event.COMPLETE, onSiteLoad);
			myLoader.load(urlRequest);
		}
		
		/**
		 * Error parser
		 **/
		private function onError(e:IOErrorEvent):void{
			dispatchError(e.text, "IO Error happened in MusicSearch class");
			//trace('io-error: '+e.text);
		}
		
		/**
		 * Result parser on reciev
		 **/
		private function onSiteLoad(evt:Event):void{
			// add event listener and load url
			myLoader.removeEventListener(Event.COMPLETE, onSiteLoad);
			// close loader
			//myLoader.close();
			
			// get result data
			var data:String = evt.target.data;
			
			this.data = data;
			
			// dispatch error
			if(data.match('id="myprofile"') == null){
				// call event
				dispatchError("Неверный логин или пароль вконтакте!");	
			}else{
				dispatchEvent(new Event(Worker.INITIALIZED));
			}
			data = null;
		}
		
		/**
		 * 
		 * @param query - search query
		 * 
		 * Searches vkontakte.ru for mp3 for given query
		 */
		public function findData(query:String, hd:int = 0, finddur:int = 0):void{
			// http://vkontakte.ru/gsearch.php?q=%20Sonic%20Youth&section=audio&ajax=1&auto=1&c%5Bq%5D=Naoki%20Kenji&c%5Bsection%5D=audio
			// http://vkontakte.ru/gsearch.php?q="+query+"&section=audio
			urlRequest.url = "http://vkontakte.ru/gsearch.php?q="+escapeMultiByte(query)+"&section=video&ajax=1";
			// add event listener and load url
			myLoader.addEventListener(Event.COMPLETE, onSearchLoad);
			
			// set duration
			this.finddur = finddur;
			
			// enable cyrilic
			//System.useCodePage = true;
			
			var vars:URLVariables = new URLVariables();
			vars['c[q]'] = query;
			if(hd > 0){
				vars['c[hd]'] = "1";
				//vars['c[quality]'] = hd.toString();
			}
			vars['c[section]'] = "video";
			//vars.offset = 0;
			vars.auto = 1;
			vars.preload = 1;

			urlRequest.method = URLRequestMethod.POST;
			urlRequest.data = vars;
			urlRequest.requestHeaders['Referer'] = "http://vkontakte.ru/gsearch.php?q="+CUtils.urlEncode(query)+"&section=video";
			
			// remove default error cathcer
			myLoader.removeEventListener(IOErrorEvent.IO_ERROR, onError);
			// add speacial
			myLoader.addEventListener(IOErrorEvent.IO_ERROR, onTrackError);
			
			// load request
			myLoader.load(urlRequest);
		}
		
		/**
		 * 
		 * @param evt
		 * Result parser on recieve
		 */
		private function onSearchLoad(evt:Event):void{
			// add event listener and load url
			myLoader.removeEventListener(Event.COMPLETE, onSearchLoad);
			// close 
			//myLoader.close();
			
			// get result data
			var data:String = String(evt.target.data);

			data = data.replace(/\n/gs, "").replace(/\t/gs, "").replace(/\r/gs, "");
			data = data.replace(/\\n/gs, "").replace(/\\t/gs, "").replace(/\\r/gs, "");
			data = data.replace(/\\"/gs, '"');
			data = data.replace(/\\\//gs, "/");
			
			// create regex
			var re:RegExp;
			// create res array
			var res:Array;
			
			// form regexp
			//re = new RegExp(/div id="video.+?".+?{"host":"(.+?)","vtag":"(.+?)".+?"md_title":"(.+?)".+?"ltag":"(.+?)".+?"uid":"(.+?)","hd":(.+?),.+?}.+?class="ainfo".+?style='color.+?'>(.+?)<\/b>/gs);
			re = new RegExp(/{"uid":"(.+?)".+?"host":"(.+?)","vtag":"(.+?)","ltag":"(.+?)".+?"md_title":"(.+?)".+?"hd":(.+?),.+?"thumb":"(.+?)"}.+?<div class="ainfo"><b style='color:#000'>(.+?)<\/b>/gs);
			// execute regexp on data
			res = re.exec(data);
			
			//trace(data);
			//trace(ObjectUtil.toString(res));
			
			var info:Object;
			var dupes:Array = new Array();
			results = new ArrayCollection();
			
			while(res != null){
				if(String(res[1]).length < 3){
					res = re.exec(data);
					continue;
				}
				info = new Object();
				info.uid = res[1];
				info.host = res[2];
				info.vtag = res[3];
				info.ltag = res[4];
				info.title = CUtils.prepareVkVideoTitle(res[5]);
				info.hd = res[6];
				info.thumb = String(res[7]).replace(/\\\\\//gs, "/");
				info.len = res[8];
				if(int(info.hd) == 0){
					info.url = 'http://cs'+info.host+'.vkontakte.ru/u'+info.uid+'/video/'+
						info.vtag+'.flv';
					info.hd_text = "260p";
				}else{
					info.url = 'http://cs'+info.host+'.vkontakte.ru/u'+info.uid+'/video/'+
						info.vtag+'.'+hdDef[int(info.hd)-1][1]+'.mp4';
					info.hd_text = hdDef[int(info.hd)-1][1]+"p";
				}
				
				if(dupes.indexOf(info.title+info.hd+info.len) == -1){
					dupes.push(info.title+info.hd+info.len);
					// look for dupes
					results.addItem(info);
				}
				
				res = re.exec(data);
			}
			
			//System.useCodePage = true;
			
			// erase vars
			dupes = null;
			info = null;
			data = null;
			re = null;
			res = null;
			
			// init end
			end();
		}
		
		/**
		 * 
		 * @param e
		 * 
		 * Catches load error for track search 
		 */
		private function onTrackError(e:IOErrorEvent):void{
			// set result
			results = null;
			
			// init end
			end();
		}
		
		private function end():void{			
			// turn off cyrilic
			//System.useCodePage = false;
			
			// call event
			dispatchEvent(new Event(Worker.COMPLETE));
		}
		
	}
}