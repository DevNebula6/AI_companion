// import 'dart:io';
// import 'package:ai_companion/auth/supabase_client_singleton.dart';
// import 'package:ai_companion/auth/custom_auth_user.dart';
// import 'package:ai_companion/data/user/user_table.dart';
// import 'package:crypto/crypto.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:logging/logging.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';


// class UserRepository {
//   late final _supabase = SupabaseClientManager().client;
//   static const int maxSizeBytes = 4 * 1024 * 1024; // 4MB
//   static const int targetSizeBytes = 2 * 1024 * 1024; // 2MB
//   static const validExtensions = ['.jpg', '.jpeg', '.png'];
//     final _log = Logger('UserRepository');

    
//   Future<String> uploadProfileImage({
//     required File? imageFile, 
//     required String uid,
//     required bool upload,
//     }) async {
//     try {
//       if (imageFile != null) {

//       // 1. Validate file type first (cheap operation)
//       final fileExt = path.extension(imageFile.path).toLowerCase();
//       if (!validExtensions.contains(fileExt)) {
//         throw InvalidFileTypeException();
//       }

//       // 2. Validate original size
//       if (imageFile.lengthSync() <= targetSizeBytes) {
//         // Skip compression if file is already small enough
//         return _uploadFileAndGetURL(imageFile, uid, upload);
//       }

//       // 3. Compress only if needed
//       final compressedImage = await _compressImage(
//         imageFile,
//         targetSize: maxSizeBytes,
//       );
  
//       // 4. Upload and get URL
//       return _uploadFileAndGetURL(compressedImage, uid, upload);

//       } else {
        
//         return '';
//       }
//     } catch (e) {
//       throw ProfileImageUploadException();
//     }
//   }
  
//   Future<String> _uploadFileAndGetURL(
//     File file, 
//     String uid, 
//     bool upload,
//   ) async {
//     final bytes = await file.readAsBytes();
//     final hash = sha256.convert(bytes).toString().substring(0, 10);
//     final fileName = '${uid}_$hash${path.extension(file.path)}';
//     print('profile filename-$fileName');
//     if (upload) {
//       await _supabase.storage
//           .from('profile_images')
//           .upload(
//             fileName, 
//             file,
//             fileOptions: const FileOptions(
//               cacheControl: '3600',
//               upsert: true
//             ),
//           );
//     }

//     return _supabase.storage
//         .from('profile_images')
//         .getPublicUrl(fileName);
    
//   }

//   Future<File> _compressImage(
//     File file, 
//     {required int targetSize
//   }) async {
//     int quality = 80;
//     File? result;
    
//     // Progressive compression
//     while (quality > 20) {
//       final dir = path.dirname(file.path);
//       final name = path.basenameWithoutExtension(file.path);
//       final ext = path.extension(file.path);
//       final targetPath = path.join(dir, '${name}_compressed$ext');

//       result = File((await FlutterImageCompress.compressAndGetFile(
//         file.absolute.path,
//         targetPath,
//         quality: quality,
//         minWidth: 1024,
//         minHeight: 1024,
//       ))?.path ?? '');

//       if (result.lengthSync() <= targetSize) break;
//       quality -= 20;
//     }

//     if (result == null) throw FailedToCompressImageException();
//     return result;
//   }


//   Future<CustomAuthUser?> getUserInfo({required CustomAuthUser? user}) async {
//     try {
//       final userTable = UserTable();
      
//       if (user == null) {
//         _log.warning('No UID provided for getUserInfo');
//         return null;
//       }
//       final uid = user.id;
//       // Attempt to get user data
//       final response = await _supabase
//           .from(userTable.tablename)
//           .select()
//           .eq(userTable.uidColumn, uid)
//           .single();
      
//       _log.fine('User data retrieved successfully for UID: $uid');
       
//       return user.copyWith(
//         username: response[userTable.userNameColumn] ,
//         fullName: response[userTable.fullnameColumn] ,
//         avatarUrl: response[userTable.imgurlColumn] ,
//       );

//     } on PostgrestException catch (e) {
//       if (e.code == 'PGRST116') {
//         _log.info('User not found in database, needs creation');
//         return null;
//       }
//       _log.severe('Database error while fetching user: ${e.message}');
//       throw UserInfoFetchException();
      
//     } catch (e) {
//       _log.severe('Unexpected error in getUserInfo: $e');
//       throw UserInfoFetchException();
//     }
//   }
// }
