
//		if (elements[i].id && window.GetPrefs) {
//			var elTop = GetPrefs(elements[i].id + '.style.top');
//			var elLeft = GetPrefs(elements[i].id + '.style.left');
//
//			if (elTop && elLeft) {
//				elmnt.style.left = elLeft;
//				elmnt.style.top = elTop;
//			}
//
//			//var elTop = window.elementPosCounter || 1;
//			//var elTop = GetPrefs(elements[i].id + '.style.top');
//			//window.elementPosCounter += elmnt.style.height;
//
//			//var elLeft = GetPrefs(elements[i].id + '.style.left') || 1;
//
//			//if (elTop && elLeft) {
//				//elmnt.style.left = elLeft;
//				//elmnt.style.top = elTop;
//			//}
//		} else {
//			//alert('DEBUG: dragging.js: warning: id and/or GetPrefs() missing');
//		}
//		//dragElement(elements[i], firstTitlebar);





<div id='photos-preview'></div>
<input type="file" id="fileupload" multiple (change)="handleFileInput($event.target.files)" />
JS:

 function handleFileInput(fileList: FileList) {
        const preview = document.getElementById('photos-preview');
        Array.from(fileList).forEach((file: File) => {
            const reader = new FileReader();
            reader.onload = () => {
              var image = new Image();
              image.src = String(reader.result);
              preview.appendChild(image);
            }
            reader.readAsDataURL(file);
        });
    }




function previewImages() {

  var preview = document.querySelector('#preview');

  if (this.files) {
    [].forEach.call(this.files, readAndPreview);
  }

  function readAndPreview(file) {

    // Make sure `file.name` matches our extensions criteria
    if (!/\.(jpe?g|png|gif)$/i.test(file.name)) {
      return alert(file.name + " is not an image");
    } // else...

    var reader = new FileReader();

    reader.addEventListener("load", function() {
      var image = new Image();
      image.height = 100;
      image.title  = file.name;
      image.src    = this.result;
      preview.appendChild(image);
    });

    reader.readAsDataURL(file);

  }

}

document.querySelector('#file-input').addEventListener("change", previewImages);



<script type="text/javascript">function addEvent(b,a,c){if(b.addEventListener){b.addEventListener(a,c,false);return true}else return b.attachEvent?b.attachEvent("on"+a,c):false}
var cid,lid,sp,et,pint=6E4,pdk=1.2,pfl=20,mb=0,mdrn=1,fixhead=0,dmcss='//d217i264rvtnq0.cloudfront.net/styles/mefi/dark-mode20200421.2810.css';


