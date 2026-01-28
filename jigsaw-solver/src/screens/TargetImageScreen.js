import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  SafeAreaView,
  Alert,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useImages } from '../context/ImageContext';

const TargetImageScreen = ({ navigation }) => {
  const { targetImage, setTargetImage } = useImages();

  const pickImage = async (useCamera = false) => {
    try {
      let result;

      if (useCamera) {
        const cameraPermission = await ImagePicker.requestCameraPermissionsAsync();
        if (!cameraPermission.granted) {
          Alert.alert('Permission Required', 'Camera permission is required to take photos.');
          return;
        }
        result = await ImagePicker.launchCameraAsync({
          mediaTypes: ['images'],
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      } else {
        const mediaLibraryPermission = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (!mediaLibraryPermission.granted) {
          Alert.alert('Permission Required', 'Photo library permission is required.');
          return;
        }
        result = await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      }

      if (!result.canceled && result.assets[0]) {
        setTargetImage({
          uri: result.assets[0].uri,
          width: result.assets[0].width,
          height: result.assets[0].height,
        });
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to pick image. Please try again.');
    }
  };

  const showImageOptions = () => {
    Alert.alert('Select Image', 'Choose how to add your target image', [
      { text: 'Take Photo', onPress: () => pickImage(true) },
      { text: 'Choose from Library', onPress: () => pickImage(false) },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Target Image</Text>
        <Text style={styles.subtitle}>
          Upload a photo of the empty puzzle hole that needs to be filled
        </Text>
      </View>

      <View style={styles.content}>
        {targetImage ? (
          <View style={styles.imageContainer}>
            <Image source={{ uri: targetImage.uri }} style={styles.previewImage} />
            <View style={styles.imageInfo}>
              <Text style={styles.infoText}>
                {targetImage.width} x {targetImage.height}
              </Text>
            </View>
          </View>
        ) : (
          <TouchableOpacity style={styles.placeholder} onPress={showImageOptions}>
            <Text style={styles.placeholderIcon}>+</Text>
            <Text style={styles.placeholderText}>Tap to add image</Text>
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.actions}>
        {targetImage && (
          <TouchableOpacity style={styles.changeButton} onPress={showImageOptions}>
            <Text style={styles.changeButtonText}>Change Image</Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity
          style={[styles.continueButton, !targetImage && styles.continueButtonDisabled]}
          onPress={() => targetImage && navigation.navigate('CandidateImages')}
          disabled={!targetImage}
        >
          <Text style={styles.continueButtonText}>
            {targetImage ? 'Continue to Candidates' : 'Add image to continue'}
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.tips}>
        <Text style={styles.tipsTitle}>Tips for best results:</Text>
        <Text style={styles.tipItem}>• Take a clear, well-lit photo</Text>
        <Text style={styles.tipItem}>• Focus on the empty hole area</Text>
        <Text style={styles.tipItem}>• Avoid shadows and reflections</Text>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f7fa',
  },
  header: {
    paddingHorizontal: 24,
    paddingTop: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a2e',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: '#666',
    lineHeight: 22,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    justifyContent: 'center',
  },
  placeholder: {
    aspectRatio: 1,
    backgroundColor: '#fff',
    borderRadius: 20,
    borderWidth: 2,
    borderColor: '#e0e0e0',
    borderStyle: 'dashed',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderIcon: {
    fontSize: 48,
    color: '#4285f4',
    marginBottom: 12,
  },
  placeholderText: {
    fontSize: 16,
    color: '#666',
  },
  imageContainer: {
    aspectRatio: 1,
    borderRadius: 20,
    overflow: 'hidden',
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 5,
  },
  previewImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  imageInfo: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    padding: 12,
  },
  infoText: {
    color: '#fff',
    fontSize: 14,
    textAlign: 'center',
  },
  actions: {
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
  changeButton: {
    padding: 14,
    alignItems: 'center',
    marginBottom: 8,
  },
  changeButtonText: {
    color: '#4285f4',
    fontSize: 16,
    fontWeight: '500',
  },
  continueButton: {
    backgroundColor: '#4285f4',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
  },
  continueButtonDisabled: {
    backgroundColor: '#ccc',
  },
  continueButtonText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '600',
  },
  tips: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  tipsTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 8,
  },
  tipItem: {
    fontSize: 13,
    color: '#888',
    marginBottom: 4,
  },
});

export default TargetImageScreen;
