import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // For base64 encoding
import 'dart:io'; // For File handling

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronTrack',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Create WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NativeApp',
        onMessageReceived: (JavaScriptMessage message) {
          print('Message from JavaScript: ${message.message}');
          if (message.message == 'openFilePicker') {
            _openFilePicker(context, isProfilePicture: true);
          } else if (message.message == 'openLogoFilePicker') {
            _openFilePicker(context, isProfilePicture: false);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Inject our JavaScript helper
            _injectFilePickerHelper();
          },
        ),
      );

    // Load the website
    _controller.loadRequest(Uri.parse('https://www.irontrack.ee'));
  }

  void _injectFilePickerHelper() {
    _controller.runJavaScript('''
      (function() {
        console.log("Setting up improved file picker integration");
        
        // Function to intercept profile picture uploads
        function setupProfilePictureUpload() {
          // Find profile picture upload elements
          var profileButtons = Array.from(document.querySelectorAll('button, label'))
            .filter(el => el.textContent && el.textContent.includes('Upload Profile Picture'));
            
          profileButtons.forEach(function(button) {
            if (button.dataset.processed) return;
            button.dataset.processed = "true";
            
            console.log("Found profile picture upload button");
            
            button.addEventListener('click', function(e) {
              console.log("Profile picture button clicked");
              e.preventDefault();
              e.stopPropagation();
              
              if (window.NativeApp) {
                window.NativeApp.postMessage('openFilePicker');
              }
              
              return false;
            });
          });
        }
        
        // Function to intercept logo uploads - specifically for Material-UI pattern
        function setupLogoUpload() {
          // Target Material-UI specific pattern - looking for Upload Logo button
          document.querySelectorAll('button').forEach(function(button) {
            // Check if this button contains "Upload Logo" text
            if (button.textContent && button.textContent.trim() === 'Upload Logo') {
              // Skip if already processed
              if (button.dataset.processed) return;
              button.dataset.processed = "true";
              
              console.log("Found Upload Logo button");
              
              // Capture the associated input element
              var hiddenInput = null;
              
              // Check if input is inside the button (Material-UI pattern)
              hiddenInput = button.querySelector('input[type="file"]');
              
              // If not inside, check if it's a sibling or in the parent
              if (!hiddenInput) {
                var parent = button.parentElement;
                if (parent) {
                  hiddenInput = parent.querySelector('input[type="file"]');
                }
              }
              
              // Store the reference to input for use in the handler
              button.dataset.inputRef = hiddenInput ? true : false;
              
              button.addEventListener('click', function(e) {
                console.log("Logo upload button clicked");
                e.preventDefault();
                e.stopPropagation();
                
                // Call our native handler
                if (window.NativeApp) {
                  window.NativeApp.postMessage('openLogoFilePicker');
                }
                
                return false;
              });
            }
          });
          
          // Also check for MaterialUI's label + hidden input pattern
          document.querySelectorAll('label').forEach(function(label) {
            if (label.textContent && label.textContent.includes('Upload Logo')) {
              if (label.dataset.processed) return;
              label.dataset.processed = "true";
              
              console.log("Found Upload Logo label");
              
              // Check for input inside or associated with the label
              var hiddenInput = label.querySelector('input[type="file"]');
              
              label.addEventListener('click', function(e) {
                console.log("Logo upload label clicked");
                e.preventDefault();
                e.stopPropagation();
                
                if (window.NativeApp) {
                  window.NativeApp.postMessage('openLogoFilePicker');
                }
                
                return false;
              });
            }
          });
        }
        
        // Run setup functions
        setupProfilePictureUpload();
        setupLogoUpload();
        
        // Set up observer to monitor for DOM changes
        var observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.addedNodes.length) {
              // Check if any relevant elements were added
              setupProfilePictureUpload();
              setupLogoUpload();
            }
          });
        });
        
        // Start observing
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        // Also look for page navigation events
        var oldHref = window.location.href;
        setInterval(function() {
          if (oldHref !== window.location.href) {
            oldHref = window.location.href;
            console.log("Navigation detected, setting up handlers again");
            setTimeout(function() {
              setupProfilePictureUpload();
              setupLogoUpload();
            }, 1000); // Wait for React to render
          }
        }, 500);
      })();
    ''');
  }

  Future<void> _openFilePicker(BuildContext context, {bool isProfilePicture = true}) async {
    // Initialize image picker
    final ImagePicker picker = ImagePicker();

    try {
      // Open the image picker and get the selected image
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        // Convert the image to base64 for injection into WebView
        final bytes = await pickedImage.readAsBytes();
        final base64String = base64Encode(bytes);

        // Get the filename
        final String fileName = pickedImage.name;

        // Process the image based on type
        if (isProfilePicture) {
          _injectProfileImageData(base64String, fileName);
        } else {
          _injectLogoImageData(base64String, fileName);
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to select image: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _injectProfileImageData(String base64String, String fileName) {
    _controller.runJavaScript('''
    (function() {
      console.log("Profile image selected: ${fileName}");
      
      fetch("data:image/jpeg;base64,${base64String}")
        .then(response => response.blob())
        .then(blob => {
          // Create a File object
          var file = new File([blob], "${fileName}", {type: "image/jpeg"});
          
          // Find the profile picture file input
          var fileInput = document.getElementById('profile-pic-input');
          
          if (fileInput) {
            try {
              // Set the file using DataTransfer API
              var dataTransfer = new DataTransfer();
              dataTransfer.items.add(file);
              fileInput.files = dataTransfer.files;
              
              // Trigger change event
              var event = new Event('change', { bubbles: true });
              fileInput.dispatchEvent(event);
              
              console.log("Profile image injected successfully");
              showToast("Profile picture selected");
            } catch (err) {
              console.error("Error setting file:", err);
              
              // Try alternative approach
              try {
                const dt = new ClipboardEvent('').clipboardData || new DataTransfer();
                dt.items.add(file);
                fileInput.files = dt.files;
                fileInput.dispatchEvent(new Event('change', {bubbles: true}));
                showToast("Profile picture selected");
              } catch (fallbackErr) {
                console.error("Both file injection methods failed:", fallbackErr);
              }
            }
          } else {
            console.error("Could not find profile file input");
          }
        })
        .catch(error => {
          console.error("Error creating file:", error);
        });
        
      // Helper function to show toast
      function showToast(message) {
        var toast = document.createElement('div');
        toast.innerText = message;
        toast.style.position = "fixed";
        toast.style.bottom = "20px";
        toast.style.left = "50%";
        toast.style.transform = "translateX(-50%)";
        toast.style.backgroundColor = "#4CAF50";
        toast.style.color = "white";
        toast.style.padding = "10px 20px";
        toast.style.borderRadius = "5px";
        toast.style.zIndex = "9999";
        document.body.appendChild(toast);
        
        setTimeout(function() {
          toast.style.opacity = "0";
          toast.style.transition = "opacity 0.5s";
          setTimeout(function() {
            document.body.removeChild(toast);
          }, 500);
        }, 3000);
      }
    })();
    ''');
  }

  void _injectLogoImageData(String base64String, String fileName) {
    _controller.runJavaScript('''
    (function() {
      console.log("Logo image selected: ${fileName}");
      
      // Create a blob from the base64 data
      fetch("data:image/jpeg;base64,${base64String}")
        .then(response => response.blob())
        .then(blob => {
          // Create a File object
          var file = new File([blob], "${fileName}", {type: "image/jpeg"});
          
          // SPECIFICALLY TARGETING MATERIAL-UI LOGO UPLOAD PATTERN
          // First find the logo upload button
          var logoButton = Array.from(document.querySelectorAll('button, label'))
            .find(el => el.textContent && el.textContent.includes('Upload Logo'));
          
          var fileInput = null;
          
          if (logoButton) {
            console.log("Found logo button for file injection");
            
            // Try several patterns to find the associated input
            // 1. Check inside the button
            fileInput = logoButton.querySelector('input[type="file"]');
            
            // 2. Check parent
            if (!fileInput && logoButton.parentElement) {
              fileInput = logoButton.parentElement.querySelector('input[type="file"]');
            }
            
            // 3. Check container
            if (!fileInput) {
              // Move up to potential container
              var container = logoButton.closest('.MuiCard-root') || 
                              logoButton.closest('.MuiCardContent-root') ||
                              logoButton.closest('form');
              
              if (container) {
                fileInput = container.querySelector('input[type="file"]');
              }
            }
          }
          
          // If still not found, try a broader search just for this specific app
          if (!fileInput) {
            console.log("Trying broader search for file input");
            var allInputs = document.querySelectorAll('input[type="file"]');
            
            // Look for inputs in the vicinity of text containing "Upload Logo"
            if (allInputs.length > 0) {
              var logoElements = document.querySelectorAll('button:contains("Upload Logo"), span:contains("Upload Logo")');
              
              if (logoElements.length > 0) {
                // Find closest input to any of these elements
                for (var i = 0; i < logoElements.length; i++) {
                  var element = logoElements[i];
                  var closestCard = element.closest('.MuiCard-root');
                  
                  if (closestCard) {
                    fileInput = closestCard.querySelector('input[type="file"]');
                    if (fileInput) break;
                  }
                }
              }
              
              // If still not found, just use the most recently added file input
              // This is a fallback heuristic specifically for this app
              if (!fileInput && window.location.href.includes('/my-affiliate')) {
                fileInput = allInputs[allInputs.length - 1];
              }
            }
          }
          
          if (fileInput) {
            // We found the input, now attempt to set the file
            try {
              console.log("Attempting to set file on input:", fileInput);
              
              // Try using DataTransfer API
              var dataTransfer = new DataTransfer();
              dataTransfer.items.add(file);
              fileInput.files = dataTransfer.files;
              
              // Trigger the change event
              var changeEvent = new Event('change', { bubbles: true });
              fileInput.dispatchEvent(changeEvent);
              
              console.log("Logo image injected successfully");
              showToast("Logo uploaded successfully");
            } catch (err) {
              console.error("Error setting logo file:", err);
              
              // Try alternative approach
              try {
                const dt = new ClipboardEvent('').clipboardData || new DataTransfer();
                dt.items.add(file);
                fileInput.files = dt.files;
                
                // Trigger all possible events
                fileInput.dispatchEvent(new Event('change', {bubbles: true}));
                fileInput.dispatchEvent(new Event('input', {bubbles: true}));
                
                showToast("Logo uploaded successfully");
              } catch (fallbackErr) {
                console.error("Both logo file injection methods failed:", fallbackErr);
                showToast("Failed to set logo file. Please try again.");
              }
            }
          } else {
            console.error("Could not find any logo file input element");
            showToast("Could not find logo upload element");
          }
        })
        .catch(error => {
          console.error("Error creating logo file:", error);
        });
        
      // Helper function to show toast
      function showToast(message) {
        var toast = document.createElement('div');
        toast.innerText = message;
        toast.style.position = "fixed";
        toast.style.bottom = "20px";
        toast.style.left = "50%";
        toast.style.transform = "translateX(-50%)";
        toast.style.backgroundColor = "#4CAF50";
        toast.style.color = "white";
        toast.style.padding = "10px 20px";
        toast.style.borderRadius = "5px";
        toast.style.zIndex = "9999";
        document.body.appendChild(toast);
        
        setTimeout(function() {
          toast.style.opacity = "0";
          toast.style.transition = "opacity 0.5s";
          setTimeout(function() {
            document.body.removeChild(toast);
          }, 500);
        }, 3000);
      }
    })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}