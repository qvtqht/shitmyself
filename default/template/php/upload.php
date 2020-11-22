<?php

include_once('utils.php');

$optStripMetaData = 0; // option to strip meta data
if (GetConfig('admin/php/upload/strip_exif')) {
    if (isset($_POST) && isset($_POST['chkStripMetaData'])) {
        $optStripMetaData = 1;
    } else {
        $optStripMetaData = 0;
    }
}

if (!empty($_FILES['uploaded_file'])) {
	$basePath = "image/";
	WriteLog('$basePath = ' . $basePath);
	WriteLog('$_FILES: ' . print_r($_FILES, 1));

	if ($_FILES['uploaded_file']['error'] && !is_array($_FILES['uploaded_file']['error'])) {
		// check for errors, one file
		// See https://www.php.net/manual/en/features.file-upload.errors.php
		echo "There was an error uploading the file.";
		if ($_FILES['uploaded_file']['error'] == 1) {
			echo "The problem may be related to the file's size";
		}
	}
	if ($_FILES['uploaded_file']['error'] && is_array($_FILES['uploaded_file']['error'])) {
		// check for errors, multiple files #untested
		// See https://www.php.net/manual/en/features.file-upload.errors.php
		foreach ($_FILES['uploaded_file']['error'] as $error) {
			if ($error) {
				echo "There was an error uploading the file.";
				if ($_FILES['uploaded_file']['error'] == 1) {
					echo "The problem may be related to the file's size";
				}
			}
		}
	}


	if (1) {
		if ($_FILES['uploaded_file']) {
			if (is_array($_FILES['uploaded_file']['name'])) {
			#multi
				for ($iUploadedFile = 0; $iUploadedFile < count($_FILES['uploaded_file']['name']); $iUploadedFile++) {
					WriteLog('$iUploadedFile = ' . $iUploadedFile);
// 					WriteLog($_FILES['uploaded_file']['name'][$iUploadedFile] . '<br>');
// 					WriteLog($_FILES['uploaded_file']['type'][$iUploadedFile] . '<br>');
// 					WriteLog($_FILES['uploaded_file']['tmp_name'][$iUploadedFile] . '<br>');
// 					WriteLog($_FILES['uploaded_file']['error'][$iUploadedFile] . '<br>');
// 					print $_FILES['uploaded_file']['size'][$iUploadedFile] . '<br>';
// 					print '<hr>';

					$path = $basePath . basename($_FILES['uploaded_file']['name'][$iUploadedFile]);
					$tempName = $_FILES['uploaded_file']['tmp_name'][$iUploadedFile];
					WriteLog('trying to move_uploaded_file(' . $tempName . ',' . $path . ')');
					$path = $basePath . time() . '_' . basename($_FILES['uploaded_file']['name'][$iUploadedFile]);
					$moveFileResult = move_uploaded_file($tempName, $path);

					if (file_exists($path)) {
						#todo make this nicer
                		if (!$moveFileResult) {
                			WriteLog("There was an error uploading the file, please try again! move_uploaded_file() returned: [$moveFileResult]");
                			print "There was a problem uploading the file, please try again!";
                		} else {
                			$pwd = getcwd();
                			WriteLog('$pwd = ' . $pwd);
                			$scriptDir = GetScriptDir();
                			WriteLog('$scriptDir = ' . $scriptDir);

                			if (GetConfig('admin/php/post/index_file_on_post') && defined($path) && $path && file_exists($path)) {
                			    if ($optStripMetaData) {
                			        WriteLog('$optStripMetaData: here would call convert $file1 -strip $file2');
                                }
                				IndexImageFile($path);
							}

							RedirectWithResponse('/write.html', 'Thank you! Upload received and processing.');
                		}
					}
				}
			}
			else if (isset($_FILES['uploaded_file']['name'])) {
			#single
				$path = $basePath . basename($_FILES['uploaded_file']['name']);
				WriteLog('trying to move_uploaded_file(' . $_FILES['uploaded_file']['tmp_name'] . ',' . $path . ')');
				if (file_exists($path)) {
					#todo make this nicer
					$path = $basePath . time() . '_' . basename($_FILES['uploaded_file']['name']);
				}

				$moveFileResult = move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $path);

				if (!$moveFileResult) {
					WriteLog("There was an error uploading the file, please try again! move_uploaded_file() returned: [$moveFileResult]");
					echo "There was a problem uploading the file, please try again!";
				} else {
					# remember current working directory, we'll need it later
					$pwd = getcwd();
					WriteLog('$pwd = ' . $pwd);

					$scriptDir = GetScriptDir();
					WriteLog('$scriptDir = ' . $scriptDir);

					if (GetConfig('admin/php/post/index_file_on_post') && $path) {
						// #todo still BROKEN
						if ($pwd) {
							WriteLog("cd $pwd");
							WriteLog(`cd $pwd`);
						}

						WriteLog("cd $scriptDir ; ./index.pl \"html/$path\"");
						WriteLog(`cd $scriptDir ; ./index.pl "html/$path"`);

						if ($pwd) {
							WriteLog("cd $pwd");
							WriteLog(`cd $pwd`);
						}

						$hash = GetFileHash("$path");

						WriteLog("cd $scriptDir ; ./pages.pl \"$hash\"");
						WriteLog(`cd $scriptDir ; ./pages.pl "$hash"`);

						if (isset($replyTo) && $replyTo) {
							WriteLog("\$replyTo = $replyTo");
							if (IsItem($replyTo)) {
								WriteLog("cd $scriptDir ; ./pages.pl \"$replyTo\"");
								WriteLog(`cd $scriptDir ; ./pages.pl "$replyTo"`);
							}
						} else {
							WriteLog("\$replyTo not found");
						}

						if ($pwd) {
							WriteLog("cd $pwd");
							WriteLog(`cd $pwd`);
						}
					} # index_file_on_post

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
						# return to previous directory
						WriteLog("cd $pwd");
						WriteLog(`cd $pwd`);
					}

					$hash = GetFileHash($path); // get file's hash
					$fileHtmlPath = './' . GetHtmlFilename($hash); // path for new html file
					$fileUrlPath = '/' . GetHtmlFilename($hash); // path for client's (browser's) path to html file

					WriteLog('upload.php: pwd() = ' . getcwd());
					WriteLog('upload.php: $hash = ' . $hash);
					WriteLog('upload.php: $fileHtmlPath = ' . $fileHtmlPath);
					WriteLog('upload.php: $fileUrlPath = ' . $fileUrlPath);
					WriteLog('upload.php: file_exists($fileHtmlPath) = ' . file_exists($fileHtmlPath));

					if (file_exists($fileHtmlPath) && $fileUrlPath) {
						RedirectWithResponse($fileUrlPath, 'Success! Thank you for uploading this beautiful picture!');
					} else {
						// good enough for now, eventually would be nice if it went to the actual item #todo
						RedirectWithResponse('/write.html', 'Thank you! Upload received and processing.');
					}
				}

			} else {
				print 'no uploaded_file #1';
			}
		} else {
			print 'no uploaded_file #2';
		}

		exit;
	}

	#print WriteLog(''); // dump log to page if in debug mode

	if (GetConfig('admin/php/debug')) {
		$html = str_replace('</body>', WriteLog('') . '</body>', $html);
	}

	print $html;
} # if (!empty($_FILES['uploaded_file']))

