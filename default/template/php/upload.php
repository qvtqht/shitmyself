<?php

include_once('utils.php');
	
if (!empty($_FILES['uploaded_file'])) {
	$basePath = "image/";
	WriteLog('$basePath = ' . $basePath);

	WriteLog(print_r($_FILES, 1));

//
//	if (file_exists($path)) {
//		//		$hash = GetFileHash($path);
//		//
//		//		// path for new html file
//		//		$fileHtmlPath = './' . GetHtmlFilename($hash);
//		//
//		//		// path for client's (browser's) path to html file
//		//		$fileUrlPath = '/' . GetHtmlFilename($hash);
//		//
//		//		$redirectUrl = '';
//		//
//		//		if (!$redirectUrl && file_exists($fileHtmlPath) && $fileUrlPath) {
//		//			$itemPostedServerResponse = "Success! Item already posted!";
//		//			$itemPostedServerResponseId = StoreServerResponse($itemPostedServerResponse);
//		//			$redirectUrl = $fileUrlPath . '?message=' . $itemPostedServerResponseId;
//		//		}
//		//
//		//		if ($redirectUrl) {
//		//			WriteLog('Location: ' . $redirectUrl);
//		//			header('Location: ' . $redirectUrl);
//		//		}
//
//		WriteLog("File with that name already exists on upload.php");
//		//echo "File with that name already exists!";
//	}
//
//
	{
		WriteLog('$_FILES: ' . print_r($_FILES, 1));

		if ($_FILES['uploaded_file']['error']) {
			// See https://www.php.net/manual/en/features.file-upload.errors.php
			echo "There was an error uploading the file.";

			if ($_FILES['uploaded_file']['error'] == 1) {
				echo "The problem may be related to the file's size";
			}
		} else {
			$path = $basePath . basename($_FILES['uploaded_file']['name']);

			WriteLog('trying to move_uploaded_file(' . $_FILES['uploaded_file']['tmp_name'] . ',' . $path . ')');

			if (file_exists($path)) {
				// #todo make this nicer
				$path = $basePath . time() . '_' . basename($_FILES['uploaded_file']['name']);
			}

			$moveFileResult = move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $path);

			if (!$moveFileResult) {
				WriteLog("There was an error uploading the file, please try again! move_uploaded_file() returned: [$moveFileResult]");
				echo "There was a problem uploading the file, please try again!";
			} else {
				// remember current working directory, we'll need it later
				$pwd = getcwd();
				WriteLog('$pwd = ' . $pwd);

				if (GetConfig('admin/php/post/update_all_on_post')) {
					WriteLog("cd .. ; ./update.pl --all");
					WriteLog(`cd .. ; ./update.pl --all`);
				}
				elseif (GetConfig('admin/php/post/update_on_post')) {
					WriteLog("cd .. ; ./update.pl");
					WriteLog(`cd .. ; ./update.pl`);
				}
				elseif (GetConfig('admin/php/post/update_item_on_post')) {
					WriteLog("cd .. ; ./update.pl \"html/$path\"");
					WriteLog(`cd .. ; ./update.pl "html/$path"`);
				}

				if ($pwd) {
					WriteLog("cd $pwd");
					WriteLog(`cd $pwd`);
				}

				$hash = GetFileHash($path);

				// path for new html file
				$fileHtmlPath = './' . GetHtmlFilename($hash);

				// path for client's (browser's) path to html file
				$fileUrlPath = '/' . GetHtmlFilename($hash);

				$redirectUrl = '';

				if (!$redirectUrl && file_exists($fileHtmlPath) && $fileUrlPath) {
					RedirectWithResponse($fileUrlPath, 'Success! Thank you for uploading this beautiful pictures!');
				} else {
					RedirectWithResponse('/post.html', 'Image uploaded, and should appear shortly after it is processed.');
				}
			}
		}
	}

	print WriteLog('');
//#todo
// if (GetConfig('admin/php/debug')) {
//	$html = str_replace('</body>', WriteLog('') . '</body>', $html);
// }
// print($html);

}