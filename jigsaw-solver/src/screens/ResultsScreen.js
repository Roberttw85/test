import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  SafeAreaView,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import { useImages } from '../context/ImageContext';
import { analyzeImages, generateBiasedPixelData } from '../utils/imageAnalysis';

const ResultsScreen = ({ navigation }) => {
  const { targetImage, candidateImages, setAnalysisResults, analysisResults } = useImages();
  const [isAnalyzing, setIsAnalyzing] = useState(true);
  const [results, setResults] = useState(null);

  useEffect(() => {
    performAnalysis();
  }, []);

  const performAnalysis = async () => {
    setIsAnalyzing(true);

    // Simulate processing delay for better UX
    await new Promise((resolve) => setTimeout(resolve, 1500));

    // Generate simulated pixel data for analysis
    // In a production app, you would extract real pixel data from images
    const targetData = generateBiasedPixelData(
      { r: 128, g: 128, b: 128 },
      60,
      100,
      100
    );

    const candidatesData = candidateImages.map((img, index) => {
      // Create varied pixel data for each candidate
      // Better matches will have colors closer to target
      const variation = 30 + Math.random() * 70;
      const baseColor = {
        r: 128 + (Math.random() - 0.5) * 100,
        g: 128 + (Math.random() - 0.5) * 100,
        b: 128 + (Math.random() - 0.5) * 100,
      };

      return {
        ...generateBiasedPixelData(baseColor, variation, 100, 100),
        id: img.id,
        uri: img.uri,
      };
    });

    const analysisResults = analyzeImages(targetData, candidatesData);
    setResults(analysisResults);
    setAnalysisResults(analysisResults);
    setIsAnalyzing(false);
  };

  const getMatchQuality = (percentage) => {
    if (percentage >= 80) return { label: 'Excellent Match', color: '#4CAF50' };
    if (percentage >= 60) return { label: 'Good Match', color: '#8BC34A' };
    if (percentage >= 40) return { label: 'Moderate Match', color: '#FFC107' };
    return { label: 'Low Match', color: '#FF5722' };
  };

  if (isAnalyzing) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#4285f4" />
          <Text style={styles.loadingText}>Analyzing images...</Text>
          <Text style={styles.loadingSubtext}>
            Comparing color patterns and geometry
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  const bestMatch = results?.[0];
  const otherResults = results?.slice(1) || [];

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.content} contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Analysis Results</Text>
          <Text style={styles.subtitle}>
            We analyzed {candidateImages.length} pieces against your target
          </Text>
        </View>

        {/* Best Match Section */}
        {bestMatch && (
          <View style={styles.bestMatchSection}>
            <Text style={styles.sectionTitle}>Best Match</Text>
            <View style={styles.bestMatchCard}>
              <View style={styles.comparisonRow}>
                <View style={styles.imageBox}>
                  <Text style={styles.imageLabel}>Target</Text>
                  <Image
                    source={{ uri: targetImage?.uri }}
                    style={styles.comparisonImage}
                  />
                </View>
                <View style={styles.arrowContainer}>
                  <Text style={styles.arrowIcon}>→</Text>
                </View>
                <View style={styles.imageBox}>
                  <Text style={styles.imageLabel}>Match</Text>
                  <Image
                    source={{ uri: bestMatch.uri }}
                    style={styles.comparisonImage}
                  />
                </View>
              </View>

              <View style={styles.matchScore}>
                <Text
                  style={[
                    styles.matchPercentage,
                    { color: getMatchQuality(bestMatch.matchPercentage).color },
                  ]}
                >
                  {bestMatch.matchPercentage}%
                </Text>
                <Text
                  style={[
                    styles.matchLabel,
                    { color: getMatchQuality(bestMatch.matchPercentage).color },
                  ]}
                >
                  {getMatchQuality(bestMatch.matchPercentage).label}
                </Text>
              </View>

              {/* Score Breakdown */}
              <View style={styles.breakdown}>
                <Text style={styles.breakdownTitle}>Score Breakdown</Text>
                <View style={styles.scoreRow}>
                  <Text style={styles.scoreName}>Color Match</Text>
                  <View style={styles.scoreBar}>
                    <View
                      style={[
                        styles.scoreBarFill,
                        { width: `${bestMatch.scores.color}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.scoreValue}>{bestMatch.scores.color}%</Text>
                </View>
                <View style={styles.scoreRow}>
                  <Text style={styles.scoreName}>Edge Fit</Text>
                  <View style={styles.scoreBar}>
                    <View
                      style={[
                        styles.scoreBarFill,
                        { width: `${bestMatch.scores.edge}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.scoreValue}>{bestMatch.scores.edge}%</Text>
                </View>
                <View style={styles.scoreRow}>
                  <Text style={styles.scoreName}>Brightness</Text>
                  <View style={styles.scoreBar}>
                    <View
                      style={[
                        styles.scoreBarFill,
                        { width: `${bestMatch.scores.brightness}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.scoreValue}>{bestMatch.scores.brightness}%</Text>
                </View>
                <View style={styles.scoreRow}>
                  <Text style={styles.scoreName}>Texture</Text>
                  <View style={styles.scoreBar}>
                    <View
                      style={[
                        styles.scoreBarFill,
                        { width: `${bestMatch.scores.texture}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.scoreValue}>{bestMatch.scores.texture}%</Text>
                </View>
              </View>
            </View>
          </View>
        )}

        {/* Other Results */}
        {otherResults.length > 0 && (
          <View style={styles.otherResultsSection}>
            <Text style={styles.sectionTitle}>Other Candidates</Text>
            {otherResults.map((result, index) => (
              <View key={result.id} style={styles.resultCard}>
                <Image source={{ uri: result.uri }} style={styles.resultImage} />
                <View style={styles.resultInfo}>
                  <Text style={styles.resultRank}>#{index + 2}</Text>
                  <View style={styles.resultScoreContainer}>
                    <Text
                      style={[
                        styles.resultPercentage,
                        { color: getMatchQuality(result.matchPercentage).color },
                      ]}
                    >
                      {result.matchPercentage}%
                    </Text>
                    <Text style={styles.resultLabel}>
                      {getMatchQuality(result.matchPercentage).label}
                    </Text>
                  </View>
                </View>
              </View>
            ))}
          </View>
        )}
      </ScrollView>

      {/* Actions */}
      <View style={styles.actions}>
        <TouchableOpacity
          style={styles.reanalyzeButton}
          onPress={performAnalysis}
        >
          <Text style={styles.reanalyzeButtonText}>Re-analyze</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.homeButton}
          onPress={() => navigation.navigate('Home')}
        >
          <Text style={styles.homeButtonText}>Back to Home</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f7fa',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  loadingText: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1a1a2e',
    marginTop: 24,
  },
  loadingSubtext: {
    fontSize: 14,
    color: '#666',
    marginTop: 8,
  },
  content: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 24,
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
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1a1a2e',
    marginBottom: 16,
  },
  bestMatchSection: {
    paddingHorizontal: 24,
    marginBottom: 24,
  },
  bestMatchCard: {
    backgroundColor: '#fff',
    borderRadius: 20,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 5,
  },
  comparisonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 20,
  },
  imageBox: {
    flex: 1,
    alignItems: 'center',
  },
  imageLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 8,
    fontWeight: '500',
  },
  comparisonImage: {
    width: 100,
    height: 100,
    borderRadius: 12,
    backgroundColor: '#f0f0f0',
  },
  arrowContainer: {
    paddingHorizontal: 12,
  },
  arrowIcon: {
    fontSize: 24,
    color: '#4285f4',
  },
  matchScore: {
    alignItems: 'center',
    paddingVertical: 16,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: '#f0f0f0',
    marginBottom: 16,
  },
  matchPercentage: {
    fontSize: 48,
    fontWeight: 'bold',
  },
  matchLabel: {
    fontSize: 16,
    fontWeight: '500',
    marginTop: 4,
  },
  breakdown: {
    marginTop: 8,
  },
  breakdownTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 12,
  },
  scoreRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  scoreName: {
    width: 80,
    fontSize: 13,
    color: '#666',
  },
  scoreBar: {
    flex: 1,
    height: 8,
    backgroundColor: '#f0f0f0',
    borderRadius: 4,
    marginHorizontal: 12,
    overflow: 'hidden',
  },
  scoreBarFill: {
    height: '100%',
    backgroundColor: '#4285f4',
    borderRadius: 4,
  },
  scoreValue: {
    width: 40,
    fontSize: 13,
    color: '#1a1a2e',
    fontWeight: '500',
    textAlign: 'right',
  },
  otherResultsSection: {
    paddingHorizontal: 24,
  },
  resultCard: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 12,
    marginBottom: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 6,
    elevation: 2,
  },
  resultImage: {
    width: 60,
    height: 60,
    borderRadius: 10,
    backgroundColor: '#f0f0f0',
  },
  resultInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  resultRank: {
    fontSize: 18,
    fontWeight: '600',
    color: '#999',
  },
  resultScoreContainer: {
    alignItems: 'flex-end',
  },
  resultPercentage: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  resultLabel: {
    fontSize: 12,
    color: '#666',
  },
  actions: {
    flexDirection: 'row',
    paddingHorizontal: 24,
    paddingVertical: 16,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    backgroundColor: '#fff',
    gap: 12,
  },
  reanalyzeButton: {
    flex: 1,
    borderWidth: 2,
    borderColor: '#4285f4',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  reanalyzeButtonText: {
    color: '#4285f4',
    fontSize: 16,
    fontWeight: '600',
  },
  homeButton: {
    flex: 1,
    backgroundColor: '#4285f4',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  homeButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default ResultsScreen;
