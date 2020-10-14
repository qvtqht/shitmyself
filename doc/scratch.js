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
